#!/usr/bin/env fish

# Fish shell setup script
# Installs Fisher and sets up completions

# Fish-specific logging functions
function log_info
    echo -e "\033[0;32m[INFO]\033[0m $argv" >&2
end

function log_warn
    echo -e "\033[1;33m[WARN]\033[0m $argv" >&2
end

function log_error
    echo -e "\033[0;31m[ERROR]\033[0m $argv" >&2
end

function log_section
    echo -e "\n\033[0;32m>>>>> $argv <<<<<\033[0m"
end

function main
    log_section "Setting up Fish shell environment"

    # Ensure completions directory exists
    if not test -d $__fish_config_dir/completions
        log_info "Creating Fish completions directory"
        mkdir -p $__fish_config_dir/completions
    end

    # Install Fisher if not present
    if not functions -q fisher
        log_info "Installing Fisher package manager"
        curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
    else
        log_info "Fisher already installed"
    end

    # Install Fisher plugins
    log_info "Installing Fisher plugins"
    set plugins \
        catppuccin/fish \
        jorgebucaran/autopair.fish \
        shoriminimoe/fish-extract \
        patrickf3139/fzf.fish \
        meaningful-ooo/sponge \
        gazorby/fish-chezmoi \
        gazorby/fish-abbreviation-tips \
        kidonng/zoxide.fish \
        SpaceShaman/autoenv.fish

    for plugin in $plugins
        if not fisher list | grep -q $plugin
            log_info "Installing Fisher plugin: $plugin"
            fisher install $plugin
        else
            log_info "Plugin already installed: $plugin"
        end
    end

    # Set up completions for various tools
    setup_completions

    # Set up bat cache if available
    if type -q bat
        log_info "Building bat cache"
        bat cache --build
    end

    log_info "Fish setup completed"
end

function setup_completions
    log_info "Setting up shell completions"

    # Homebrew completions
    if type -q brew
        log_info "Setting up Homebrew completions"
        set brew_prefix (brew --prefix)
        if test -d "$brew_prefix/share/fish/completions"
            set -p fish_complete_path "$brew_prefix/share/fish/completions"
        end
        if test -d "$brew_prefix/share/fish/vendor_completions.d"
            set -p fish_complete_path "$brew_prefix/share/fish/vendor_completions.d"
        end
    end

    # Tool-specific completions
    set completion_tools \
        chezmoi \
        flux \
        kustomize \
        kubectl \
        helm \
        tailscale \
        talosctl \
        talhelper \
        k9s

    for tool in $completion_tools
        if type -q $tool
            setup_tool_completion $tool
        end
    end

    # Special case for task (uses curl)
    if type -q task
        log_info "Setting up task completion"
        curl --silent --show-error https://raw.githubusercontent.com/go-task/task/master/completion/fish/task.fish > $__fish_config_dir/completions/task.fish
    end
end

function setup_tool_completion
    set tool $argv[1]
    set completion_file "$__fish_config_dir/completions/$tool.fish"

    log_info "Setting up $tool completion"

    switch $tool
        case chezmoi
            chezmoi completion fish --output=$completion_file
        case flux
            flux completion fish > $completion_file
        case kustomize
            kustomize completion fish > $completion_file
        case kubectl
            kubectl completion fish > $completion_file
        case helm
            helm completion fish > $completion_file
        case tailscale
            tailscale completion fish > $completion_file
        case talosctl
            talosctl completion fish > $completion_file
        case talhelper
            talhelper completion fish > $completion_file
        case k9s
            k9s completion fish > $completion_file
        case '*'
            log_warn "Unknown completion setup for: $tool"
    end
end

# Run main function
main
