#include <errno.h>
#include <sandbox.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif

/*
 * Minimal standalone repro for the Mojo "format" crash under a macOS
 * seatbelt. Denying just sysctl-read access to hw.l1dcachesize is sufficient
 * to make `mojo format` abort outside Codex.
 */

static const char *kProfile =
    "(version 1) "
    "(allow default) "
    "(deny sysctl-read (sysctl-name \"hw.l1dcachesize\"))";

static const char *kEmbeddedMojo =
    "fn main():\n"
    "    print(\"seatbelt repro\")\n";

static void usage(FILE *stream, const char *argv0) {
    fprintf(stream,
            "Usage: %s [--keep-crash-reporting] [command [args...]]\n"
            "\n"
            "Without a command, runs:\n"
            "  mojo format <generated-temp-file>\n"
            "\n"
            "By default this sets MODULAR_CRASH_REPORTING_ENABLED=0 so the\n"
            "output is the shorter stack-only crash. Pass\n"
            "--keep-crash-reporting to preserve Crashpad output.\n",
            argv0);
}

static char *create_temp_mojo_file(void) {
    char dir_template[] = "/tmp/mojo-format-repro.XXXXXX";
    char *dir = mkdtemp(dir_template);
    if (dir == NULL) {
        perror("mkdtemp");
        return NULL;
    }

    size_t path_len = strlen(dir) + strlen("/repro.mojo") + 1;
    char *path = malloc(path_len);
    if (path == NULL) {
        fprintf(stderr, "malloc failed while creating temp path\n");
        return NULL;
    }

    snprintf(path, path_len, "%s/repro.mojo", dir);

    FILE *fp = fopen(path, "w");
    if (fp == NULL) {
        perror("fopen");
        free(path);
        return NULL;
    }

    if (fputs(kEmbeddedMojo, fp) == EOF || fclose(fp) != 0) {
        perror("writing temp mojo file");
        free(path);
        return NULL;
    }

    return path;
}

int main(int argc, char **argv) {
    bool disable_crash_reporting = true;
    int cmd_index = 1;
    char *generated_path = NULL;

    if (argc > 1 && strcmp(argv[1], "--help") == 0) {
        usage(stdout, argv[0]);
        return 0;
    }

    if (argc > 1 && strcmp(argv[1], "--keep-crash-reporting") == 0) {
        disable_crash_reporting = false;
        cmd_index = 2;
    }

    if (disable_crash_reporting &&
        setenv("MODULAR_CRASH_REPORTING_ENABLED", "0", 1) != 0) {
        perror("setenv(MODULAR_CRASH_REPORTING_ENABLED)");
        return 1;
    }

    char *default_argv[] = {"mojo", "format", NULL, NULL};
    char **child_argv = NULL;
    if (cmd_index < argc) {
        child_argv = &argv[cmd_index];
    } else {
        generated_path = create_temp_mojo_file();
        if (generated_path == NULL) {
            return 1;
        }
        default_argv[2] = generated_path;
        child_argv = default_argv;
    }

    char *errorbuf = NULL;
    if (sandbox_init(kProfile, 0, &errorbuf) != 0) {
        fprintf(stderr, "sandbox_init failed: %s\n",
                errorbuf != NULL ? errorbuf : strerror(errno));
        if (errorbuf != NULL) {
            sandbox_free_error(errorbuf);
        }
        return 1;
    }

    execvp(child_argv[0], child_argv);
    perror("execvp");
    return 127;
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
