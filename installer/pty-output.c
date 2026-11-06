#include <errno.h>
#include <fcntl.h>
#include <pty.h>
#include <signal.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

static int forward_output(int master)
{
	char buffer[8192];

	for (;;) {
		ssize_t received = read(master, buffer, sizeof(buffer));
		if (received == 0 || (received < 0 && errno == EIO))
			return 0; /* The child closed the slave terminal. */
		if (received < 0) {
			if (errno == EINTR)
				continue;
			perror("read terminal output");
			return 1;
		}

		for (ssize_t sent = 0; sent < received;) {
			ssize_t written = write(STDOUT_FILENO, buffer + sent, received - sent);
			if (written < 0 && errno == EINTR)
				continue;
			if (written <= 0) {
				perror("forward terminal output");
				return 1;
			}
			sent += written;
		}
	}
}

int main(int argc, char **argv)
{
	if (argc < 2) {
		fputs("Usage: pty-output COMMAND [ARGUMENTS...]\n", stderr);
		return 2;
	}

	int master;
	pid_t child = forkpty(&master, NULL, NULL, NULL);
	if (child < 0) {
		perror("forkpty");
		return 1;
	}
	if (child == 0) {
		int input = open("/dev/null", O_RDONLY);
		if (input < 0 || dup2(input, STDIN_FILENO) < 0) {
			perror("open command input");
			_exit(1);
		}
		if (input != STDIN_FILENO)
			close(input);
		execvp(argv[1], argv + 1);
		perror(argv[1]);
		_exit(127);
	}

	signal(SIGPIPE, SIG_IGN);
	int output_status = forward_output(master);
	close(master);

	int status;
	while (waitpid(child, &status, 0) < 0) {
		if (errno == EINTR)
			continue;
		perror("waitpid");
		return 1;
	}
	if (output_status != 0)
		return output_status;
	return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
