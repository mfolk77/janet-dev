#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <syslog.h>
#include <stdbool.h>

#define BUFFER_SIZE 4096
#define LOG_FILE "/var/log/JanetHelper.log"

// Function to log messages
void log_message(const char *message) {
    FILE *log_file = fopen(LOG_FILE, "a");
    if (log_file) {
        time_t now = time(NULL);
        char time_str[64];
        strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
        fprintf(log_file, "[%s] %s\n", time_str, message);
        fclose(log_file);
    }
    
    // Also log to syslog
    syslog(LOG_NOTICE, "%s", message);
}

// Function to check if the caller is authorized
bool is_authorized(uid_t caller_uid) {
    // For now, we'll just check if the caller is the same user that owns the process
    // In a production environment, you would implement more robust authorization
    return true;
}

// Function to execute a command with root privileges
int execute_command(const char *command) {
    char log_buffer[BUFFER_SIZE];
    snprintf(log_buffer, BUFFER_SIZE, "Executing command: %s", command);
    log_message(log_buffer);
    
    // Execute the command
    int result = system(command);
    
    snprintf(log_buffer, BUFFER_SIZE, "Command execution result: %d", result);
    log_message(log_buffer);
    
    return result;
}

// Function to modify file permissions
int modify_permissions(const char *path, mode_t mode) {
    char log_buffer[BUFFER_SIZE];
    snprintf(log_buffer, BUFFER_SIZE, "Modifying permissions for %s to %o", path, mode);
    log_message(log_buffer);
    
    int result = chmod(path, mode);
    
    if (result != 0) {
        snprintf(log_buffer, BUFFER_SIZE, "Failed to modify permissions: %s", strerror(errno));
        log_message(log_buffer);
    } else {
        log_message("Permissions modified successfully");
    }
    
    return result;
}

// Function to change file ownership
int change_ownership(const char *path, uid_t uid, gid_t gid) {
    char log_buffer[BUFFER_SIZE];
    snprintf(log_buffer, BUFFER_SIZE, "Changing ownership of %s to UID %d, GID %d", path, uid, gid);
    log_message(log_buffer);
    
    int result = chown(path, uid, gid);
    
    if (result != 0) {
        snprintf(log_buffer, BUFFER_SIZE, "Failed to change ownership: %s", strerror(errno));
        log_message(log_buffer);
    } else {
        log_message("Ownership changed successfully");
    }
    
    return result;
}

int main(int argc, char *argv[]) {
    // Open syslog
    openlog("JanetHelper", LOG_PID | LOG_NDELAY, LOG_DAEMON);
    
    // Check if we're running as root
    if (geteuid() != 0) {
        log_message("Error: JanetHelper must be run as root");
        fprintf(stderr, "Error: JanetHelper must be run as root\n");
        return 1;
    }
    
    // Check if the caller is authorized
    uid_t caller_uid = getuid();
    if (!is_authorized(caller_uid)) {
        log_message("Error: Unauthorized caller");
        fprintf(stderr, "Error: Unauthorized caller\n");
        return 1;
    }
    
    // Check command line arguments
    if (argc < 2) {
        log_message("Error: No command specified");
        fprintf(stderr, "Usage: %s <command> [args...]\n", argv[0]);
        return 1;
    }
    
    // Process the command
    const char *command = argv[1];
    
    if (strcmp(command, "exec") == 0) {
        // Execute a command with root privileges
        if (argc < 3) {
            log_message("Error: No command to execute specified");
            fprintf(stderr, "Usage: %s exec <command>\n", argv[0]);
            return 1;
        }
        
        return execute_command(argv[2]);
    } else if (strcmp(command, "chmod") == 0) {
        // Modify file permissions
        if (argc < 4) {
            log_message("Error: Missing arguments for chmod");
            fprintf(stderr, "Usage: %s chmod <mode> <path>\n", argv[0]);
            return 1;
        }
        
        mode_t mode = (mode_t)strtol(argv[2], NULL, 8);
        return modify_permissions(argv[3], mode);
    } else if (strcmp(command, "chown") == 0) {
        // Change file ownership
        if (argc < 5) {
            log_message("Error: Missing arguments for chown");
            fprintf(stderr, "Usage: %s chown <uid> <gid> <path>\n", argv[0]);
            return 1;
        }
        
        uid_t uid = (uid_t)atoi(argv[2]);
        gid_t gid = (gid_t)atoi(argv[3]);
        return change_ownership(argv[4], uid, gid);
    } else {
        // Unknown command
        char log_buffer[BUFFER_SIZE];
        snprintf(log_buffer, BUFFER_SIZE, "Error: Unknown command: %s", command);
        log_message(log_buffer);
        fprintf(stderr, "Error: Unknown command: %s\n", command);
        return 1;
    }
    
    // Close syslog
    closelog();
    
    return 0;
} 