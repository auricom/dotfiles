#!/usr/bin/bash

set -Eeuo pipefail

source "${HOME}/scripts/lib/common_utils.sh"

# Trap errors and call error_handler
script_name="dotfiles_update_custom.sh"
hostname=$(hostname)
trap 'error_handler "$hostname" "$( { $BASH_COMMAND 2>&1 1>&3; } 3>&1 )"' ERR

# Chezmoi
echo "Chezmoi | ## Pulling latest from GitHub"
chezmoi git pull

# get a list of files to update that don't have local changes
FILES=$(chezmoi status | awk '/^ / {print $2}')

if [ -n "$FILES" ]; then
    echo -e "Chezmoi | \n## Updating files without local changes"
    for f in $FILES; do
        echo "... ${f}"
        chezmoi apply "~/${f}"
    done
else
    echo -e "Chezmoi | \n## No files to update without local changes"
fi

# Check for files with local changes that were NOT applied
SKIPPED_FILES=$(chezmoi status | awk '!/^ / && NF {print $2}')

if [ -n "$SKIPPED_FILES" ]; then
    skipped_count=$(echo "$SKIPPED_FILES" | wc -l)
    skipped_list=$(echo "$SKIPPED_FILES" | head -10 | tr '\n' ', ' | sed 's/,$//')
    echo -e "Chezmoi | \n## WARNING: ${skipped_count} file(s) skipped due to local changes: ${skipped_list}"
    send_pushover_message "${hostname}: chezmoi update skipped ${skipped_count} file(s) with local changes: ${skipped_list}"
fi

# Bat cache
bat cache --build

# Fish completion
echo "Fish completion..."
fish -c "~/scripts/fish_plugins_completion.fish"

# Fisher plugins
fish -c "source ~/.config/fish/functions/fisher.fish; fisher update"
