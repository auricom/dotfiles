#!/bin/bash

set -Eeuo pipefail

source "${HOME}/scripts/lib/common_utils.sh"

# Trap errors and call error_handler
script_name="dji_photo_sorter.sh"
hostname=$(hostname)
trap 'error_handler "$hostname" "$( { $BASH_COMMAND 2>&1 1>&3; } 3>&1 )"' ERR

# Source and destination directories
DJI_SOURCE_DIR="/run/media/claude/SD_Card/DCIM"
SORT_DEST_DIR="/mnt/storage.feisar.ovh/photo"

# Check if necessary directories exist
if [[ ! -d "${DJI_SOURCE_DIR}" ]] || [[ ! -d "${SORT_DEST_DIR}" ]]; then
    echo "DJI_SOURCE_DIR and SORT_DEST_DIR directories must exist."
    exit 1
fi

# Function to process DJI files
process_dji_file() {
    local file="$1"

    log_message "Processing DJI file: ${file}"

    # Extract the date from the filename (format: DJI_YYYYMMDDHHMMSS_XXXX_D.*)
    local filename=$(basename "${file}")

    # Check if the filename matches the expected DJI format
    if [[ "${filename}" =~ DJI_([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{6})_.*\..* ]]; then
        local year="${BASH_REMATCH[1]}"
        local month="${BASH_REMATCH[2]}"
        local day="${BASH_REMATCH[3]}"

        # Construct the destination directory path based on the date from filename
        local dest_path="${SORT_DEST_DIR}/${year}/${year}-${month}/${year}-${month}-${day}"

        # Create the destination directory if it doesn't exist
        mkdir -p "${dest_path}"

        # Copy the file to the destination directory
        local dest_file="${dest_path}/${filename}"

        # Check if the file already exists
        if [[ ! -f "${dest_file}" ]]; then
            cp "${file}" "${dest_file}"
            log_message "Copied: ${file} -> ${dest_file}"
        else
            # Get file sizes
            local source_size=$(stat -c %s "${file}")
            local dest_size=$(stat -c %s "${dest_file}")

            # Compare file sizes
            if [[ "${source_size}" -eq "${dest_size}" ]]; then
                log_message "Skipping copy; file exists with same size: ${dest_file}"
            else
                cp "${file}" "${dest_file}"
                log_message "Updated: ${file} -> ${dest_file} (size changed: ${dest_size} -> ${source_size})"
            fi
        fi
    else
        log_message "Skipping file (doesn't match DJI filename pattern): ${file}"
    fi
}

export -f process_dji_file log_message
export DJI_SOURCE_DIR SORT_DEST_DIR

# Start processing
log_message "Starting to process DJI files."

# Find all DJI directories
find "${DJI_SOURCE_DIR}" -type d -name "DJI_*" | while read -r dji_dir; do
    log_message "Processing directory: ${dji_dir}"

    # Process all files in the DJI directory
    find "${dji_dir}" -type f | while read -r file; do
        process_dji_file "${file}"
    done
done

log_message "DJI file processing complete."
