command -q mise; or return

# Make managed tools available before the other integrations are loaded.
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end
