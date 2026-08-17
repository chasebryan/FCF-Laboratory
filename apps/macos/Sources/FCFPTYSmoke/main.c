#include "FCFPTY.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    fcf_terminal_pty session = { .master_fd = -1, .child_pid = 0 };
    int opened = fcf_terminal_pty_open("/tmp", "/bin/zsh", 80, 24, &session);
    if (opened != 0) {
        fprintf(stderr, "unable to open PTY: %d\n", opened);
        return 1;
    }

    const char *command = "printf 'FCF_PTY_OK\\n'; exit\n";
    ssize_t written = fcf_terminal_pty_write(session.master_fd, command, strlen(command));
    if (written <= 0) {
        fprintf(stderr, "unable to write to PTY\n");
        fcf_terminal_pty_close(session.master_fd);
        return 2;
    }

    char output[16384] = {0};
    size_t used = 0;
    for (int attempt = 0; attempt < 100 && used < sizeof(output) - 1; ++attempt) {
        ssize_t count = fcf_terminal_pty_read(
            session.master_fd,
            output + used,
            sizeof(output) - used - 1
        );
        if (count > 0) {
            used += (size_t)count;
            output[used] = '\0';
            if (strstr(output, "FCF_PTY_OK") != NULL) {
                fcf_terminal_pty_close(session.master_fd);
                return 0;
            }
        } else if (count == 0) {
            break;
        }
        usleep(20000);
    }

    fprintf(stderr, "PTY output did not contain smoke marker. Output:\n%s\n", output);
    fcf_terminal_pty_close(session.master_fd);
    return 3;
}
