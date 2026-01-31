#!/usr/bin/bash

set -Eeuo pipefail

source "${HOME}/scripts/lib/common_utils.sh"

# Trap errors and call error_handler
script_name="ublue_update_custom.sh"
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

# Bat cache
bat cache --build

# Fish completion
echo "Fish completion..."
fish -c "~/scripts/fish_plugins_completion.fish"

# Fisher plugins
fish -c "source ~/.config/fish/functions/fisher.fish; fisher update"
