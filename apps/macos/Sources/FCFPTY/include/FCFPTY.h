/* FCF-Laboratory native macOS terminal emulator bridge. */
#ifndef FCF_LABORATORY_PTY_H
#define FCF_LABORATORY_PTY_H

#include <stddef.h>
#include <sys/types.h>

typedef struct {
    int master_fd;
    pid_t child_pid;
} fcf_terminal_pty;

int fcf_terminal_pty_open(const char *working_directory, const char *shell_path, int columns, int rows, fcf_terminal_pty *session);
ssize_t fcf_terminal_pty_read(int master_fd, void *buffer, size_t length);
ssize_t fcf_terminal_pty_write(int master_fd, const void *buffer, size_t length);
int fcf_terminal_pty_resize(int master_fd, int columns, int rows);
void fcf_terminal_pty_close(int master_fd);

#endif
