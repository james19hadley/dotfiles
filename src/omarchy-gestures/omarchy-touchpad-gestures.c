#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <math.h>
#include <signal.h>
#include <time.h>
#include <spawn.h>
#include <sys/wait.h>
#include <libinput.h>
#include <libudev.h>
#include <errno.h>
#include <linux/input-event-codes.h>

extern char **environ;

static volatile sig_atomic_t g_running = 1;

static void handle_sig(int sig) {
    (void)sig;
    g_running = 0;
}

static int open_restricted(const char *path, int flags, void *user_data) {
    (void)user_data;
    int fd = open(path, flags | O_CLOEXEC);
    return fd < 0 ? -errno : fd;
}

static void close_restricted(int fd, void *user_data) {
    (void)user_data;
    close(fd);
}

static const struct libinput_interface interface = {
    .open_restricted = open_restricted,
    .close_restricted = close_restricted,
};

typedef enum {
    AXIS_NONE = 0,
    AXIS_VERTICAL,
    AXIS_HORIZONTAL
} GestureAxis;

static long long current_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000LL + (ts.tv_nsec / 1000000LL);
}

static void trigger_osd(const char *icon, const char *progress_cmd) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "omarchy-osd -i %s -p $(%s) 2>/dev/null &", icon, progress_cmd);
    char *const argv[] = { (char *)"sh", (char *)"-c", cmd, NULL };
    pid_t pid;
    posix_spawnp(&pid, "/bin/sh", NULL, NULL, argv, environ);
}

static void adjust_volume(int delta_percent) {
    if (delta_percent == 0) return;
    char delta_str[32];
    if (delta_percent > 0) {
        snprintf(delta_str, sizeof(delta_str), "+%d%%", delta_percent);
    } else {
        snprintf(delta_str, sizeof(delta_str), "-%d%%", -delta_percent);
    }

    char *const argv[] = {
        (char *)"pactl",
        (char *)"set-sink-volume",
        (char *)"@DEFAULT_SINK@",
        delta_str,
        NULL
    };

    pid_t pid;
    if (posix_spawnp(&pid, "/usr/bin/pactl", NULL, NULL, argv, environ) == 0) {
        int status;
        waitpid(pid, &status, 0);
    }

    static long long last_osd = 0;
    long long now = current_time_ms();
    if (now - last_osd > 100) {
        trigger_osd("volume-high", "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if($i ~ /%$/){sub(\"%\",\"\",$i); print $i; exit}}'");
        last_osd = now;
    }
}

static void adjust_brightness(int delta_percent) {
    if (delta_percent == 0) return;
    char delta_str[32];
    if (delta_percent > 0) {
        snprintf(delta_str, sizeof(delta_str), "%d%%+", delta_percent);
    } else {
        snprintf(delta_str, sizeof(delta_str), "%d%%-", -delta_percent);
    }

    char *const argv[] = {
        (char *)"brightnessctl",
        (char *)"-q",
        (char *)"set",
        delta_str,
        NULL
    };

    pid_t pid;
    if (posix_spawnp(&pid, "/usr/bin/brightnessctl", NULL, NULL, argv, environ) == 0) {
        int status;
        waitpid(pid, &status, 0);
    }

    static long long last_osd = 0;
    long long now = current_time_ms();
    if (now - last_osd > 100) {
        trigger_osd("brightness", "brightnessctl -m 2>/dev/null | awk -F, '{gsub(\"%\",\"\",$4); print $4; exit}'");
        last_osd = now;
    }
}

static void trigger_omarchy_menu(void) {
    char *const argv[] = { (char *)"omarchy-menu", (char *)"toggle", NULL };
    pid_t pid;
    posix_spawnp(&pid, "/usr/share/omarchy/bin/omarchy-menu", NULL, NULL, argv, environ);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    // Single instance lock
    const char *runtime_dir = getenv("XDG_RUNTIME_DIR");
    char lock_path[256];
    if (runtime_dir) {
        snprintf(lock_path, sizeof(lock_path), "%s/omarchy-touchpad-gestures.lock", runtime_dir);
    } else {
        snprintf(lock_path, sizeof(lock_path), "/tmp/omarchy-touchpad-gestures-%u.lock", getuid());
    }

    int lock_fd = open(lock_path, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
    if (lock_fd >= 0) {
        struct flock fl = {
            .l_type = F_WRLCK,
            .l_whence = SEEK_SET,
            .l_start = 0,
            .l_len = 0
        };
        if (fcntl(lock_fd, F_SETLK, &fl) < 0) {
            fprintf(stderr, "[omarchy-touchpad-gestures] Another instance is already running. Exiting.\n");
            close(lock_fd);
            return 0;
        }
    }

    signal(SIGINT, handle_sig);
    signal(SIGTERM, handle_sig);
    signal(SIGCHLD, SIG_DFL);

    struct udev *udev = udev_new();
    if (!udev) {
        fprintf(stderr, "[omarchy-touchpad-gestures] Error: failed to create udev context\n");
        return 1;
    }

    struct libinput *li = libinput_udev_create_context(&interface, NULL, udev);
    if (!li) {
        fprintf(stderr, "[omarchy-touchpad-gestures] Error: failed to create libinput context\n");
        udev_unref(udev);
        return 1;
    }

    if (libinput_udev_assign_seat(li, "seat0") != 0) {
        fprintf(stderr, "[omarchy-touchpad-gestures] Error: failed to assign seat0\n");
        libinput_unref(li);
        udev_unref(udev);
        return 1;
    }

    int libinput_fd = libinput_get_fd(li);
    struct pollfd fds[1];
    fds[0].fd = libinput_fd;
    fds[0].events = POLLIN;

    printf("[omarchy-touchpad-gestures] Continuous touchpad gesture & Super-key daemon started.\n");
    fflush(stdout);

    int active_fingers = 0;
    GestureAxis axis = AXIS_NONE;
    double accum_x = 0.0;
    double accum_y = 0.0;
    
    const double STEP_PIXELS_VOL = 4.0;
    const double STEP_PIXELS_BRI = 4.0;
    const double AXIS_LOCK_THRESHOLD = 8.0;

    long long last_vol_time = 0;
    long long last_bri_time = 0;

    // Super key tap tracking
    int super_down = 0;
    int super_used_combo = 0;
    long long super_down_time = 0;

    while (g_running) {
        int ret = poll(fds, 1, 200);
        if (ret < 0) {
            if (errno == EINTR) continue;
            break;
        }

        if (ret == 0) {
            continue;
        }

        if (libinput_dispatch(li) != 0) {
            continue;
        }

        struct libinput_event *event;
        while ((event = libinput_get_event(li)) != NULL) {
            enum libinput_event_type type = libinput_event_get_type(event);

            // Handle pure Super tap vs modifier combinations
            if (type == LIBINPUT_EVENT_KEYBOARD_KEY) {
                struct libinput_event_keyboard *k = libinput_event_get_keyboard_event(event);
                uint32_t key = libinput_event_keyboard_get_key(k);
                enum libinput_key_state state = libinput_event_keyboard_get_key_state(k);

                if (key == KEY_LEFTMETA || key == KEY_RIGHTMETA) {
                    if (state == LIBINPUT_KEY_STATE_PRESSED) {
                        super_down = 1;
                        super_used_combo = 0;
                        super_down_time = current_time_ms();
                    } else if (state == LIBINPUT_KEY_STATE_RELEASED) {
                        long long duration = current_time_ms() - super_down_time;
                        if (super_down && !super_used_combo && duration >= 25 && duration <= 450) {
                            trigger_omarchy_menu();
                        }
                        super_down = 0;
                        super_used_combo = 0;
                    }
                } else {
                    if (super_down && state == LIBINPUT_KEY_STATE_PRESSED) {
                        // Any key pressed while Super was down (Space, Return, F, etc.)
                        super_used_combo = 1;
                    }
                }
            } else if (type == LIBINPUT_EVENT_GESTURE_SWIPE_BEGIN) {
                struct libinput_event_gesture *g = libinput_event_get_gesture_event(event);
                active_fingers = libinput_event_gesture_get_finger_count(g);
                axis = AXIS_NONE;
                accum_x = 0.0;
                accum_y = 0.0;
            } else if (type == LIBINPUT_EVENT_GESTURE_SWIPE_UPDATE) {
                if (active_fingers == 4) {
                    struct libinput_event_gesture *g = libinput_event_get_gesture_event(event);
                    double dx = libinput_event_gesture_get_dx(g);
                    double dy = libinput_event_gesture_get_dy(g);

                    accum_x += dx;
                    accum_y += dy;

                    if (axis == AXIS_NONE) {
                        double abs_x = fabs(accum_x);
                        double abs_y = fabs(accum_y);
                        if (abs_y >= AXIS_LOCK_THRESHOLD || abs_x >= AXIS_LOCK_THRESHOLD) {
                            axis = (abs_y >= abs_x) ? AXIS_VERTICAL : AXIS_HORIZONTAL;
                        }
                    }

                    long long now = current_time_ms();
                    if (axis == AXIS_VERTICAL && (now - last_vol_time >= 30)) {
                        int steps = (int)(-accum_y / STEP_PIXELS_VOL);
                        if (steps != 0) {
                            adjust_volume(steps);
                            accum_y += (double)steps * STEP_PIXELS_VOL;
                            last_vol_time = now;
                        }
                    } else if (axis == AXIS_HORIZONTAL && (now - last_bri_time >= 30)) {
                        int steps = (int)(accum_x / STEP_PIXELS_BRI);
                        if (steps != 0) {
                            adjust_brightness(steps);
                            accum_x -= (double)steps * STEP_PIXELS_BRI;
                            last_bri_time = now;
                        }
                    }
                }
            } else if (type == LIBINPUT_EVENT_GESTURE_SWIPE_END || 
                       type == LIBINPUT_EVENT_GESTURE_PINCH_BEGIN ||
                       type == LIBINPUT_EVENT_GESTURE_HOLD_BEGIN) {
                active_fingers = 0;
                axis = AXIS_NONE;
                accum_x = 0.0;
                accum_y = 0.0;
            }

            libinput_event_destroy(event);
        }
    }

    libinput_unref(li);
    udev_unref(udev);
    return 0;
}
