set -gx KUBE_EDITOR nano
set -gx VISUAL nano
set -gx EDITOR nano
set -gx HOMEBREW_NO_ANALYTICS 1
set -gx ANSIBLE_FORCE_COLOR true
set -gx ANSIBLE_HOST_KEY_CHECKING False
set -gx PY_COLORS true
set -gx GPG_TTY (tty)
if not set -q LC_ALL
    set -x LC_ALL "C.UTF-8"
end
