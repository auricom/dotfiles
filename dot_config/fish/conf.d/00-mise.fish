command -q mise; or return

# Three directory env loaders stay installed because they watch different files:
# - mise — tool versions and [env] in mise.toml. A bare .env is not loaded.
# - SpaceShaman/autoenv.fish — .env, and it unsets those variables on leave.
# - direnv — .envrc. It reads .env only when that file calls `dotenv`.
# Replacing any of them would drop a file convention other projects still use.

# Make managed tools available before the other integrations are loaded.
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end
