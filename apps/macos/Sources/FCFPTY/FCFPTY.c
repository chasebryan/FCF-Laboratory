/* FCF-Laboratory native macOS terminal emulator bridge. */
#include "FCFPTY.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <util.h>

int fcf_terminal_pty_open(const char *working_directory, const char *shell_path, int columns, int rows, fcf_terminal_pty *session) {
    if (session == NULL || columns <= 0 || rows <= 0) {
        return EINVAL;
    }

    struct winsize window = {0};
    window.ws_col = (unsigned short)columns;
    window.ws_row = (unsigned short)rows;

    int master_fd = -1;
    pid_t child = forkpty(&master_fd, NULL, NULL, &window);
    if (child < 0) {
        return errno == 0 ? EIO : errno;
    }

    if (child == 0) {
        if (working_directory != NULL && working_directory[0] != '\0') {
            if (chdir(working_directory) != 0) {
                _exit(126);
            }
        }

        const char *shell = shell_path;
        if (shell == NULL || shell[0] == '\0') {
            shell = getenv("SHELL");
        }
        if (shell == NULL || shell[0] == '\0') {
            shell = "/bin/zsh";
        }

        setenv("TERM", "xterm-256color", 0);
        setenv("COLORTERM", "truecolor", 0);
        execl(shell, shell, "-l", (char *)NULL);
        _exit(127);
    }

    int flags = fcntl(master_fd, F_GETFL, 0);
    if (flags >= 0) {
        (void)fcntl(master_fd, F_SETFL, flags | O_NONBLOCK);
    }

    session->master_fd = master_fd;
    session->child_pid = child;
    return 0;
}

ssize_t fcf_terminal_pty_read(int master_fd, void *buffer, size_t length) {
    ssize_t result = read(master_fd, buffer, length);
    if (result < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
        return -2;
    }
    return result < 0 ? -(ssize_t)errno : result;
}

ssize_t fcf_terminal_pty_write(int master_fd, const void *buffer, size_t length) {
    ssize_t result = write(master_fd, buffer, length);
    if (result < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
        return 0;
    }
    return result < 0 ? -(ssize_t)errno : result;
}

int fcf_terminal_pty_resize(int master_fd, int columns, int rows) {
    if (columns <= 0 || rows <= 0) {
        return EINVAL;
    }
    struct winsize window = {0};
    window.ws_col = (unsigned short)columns;
    window.ws_row = (unsigned short)rows;
    return ioctl(master_fd, TIOCSWINSZ, &window) == 0 ? 0 : errno;
}

void fcf_terminal_pty_close(int master_fd) {
    if (master_fd >= 0) {
        close(master_fd);
    }
}
