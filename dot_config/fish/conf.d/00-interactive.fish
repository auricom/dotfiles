status is-interactive; or return

set -g fish_greeting

# Configure the Fisher zoxide plugin before its conf.d snippet runs.
set -g zoxide_cmd cd
set -g zoxide_hook --on-event fish_prompt
