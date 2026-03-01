#!/bin/bash

source "${HOME}/.local/lib/pushover.sh"

# Function to handle errors
error_handler() {
    local hostname="$1"
    local stderr_content="$2"

    send_pushover_message "${hostname}: ${stderr_content}"
}

# Function to log messages to stdout
log_message() {
    DATE=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${DATE} - $1"
}
