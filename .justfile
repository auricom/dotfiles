set default-list

# Validate every shell command and all three chezmoi profiles, locally.
check:
    mise exec -- python3 scripts/check-shell.py

# Format plain shell files, then run the same validation.
fmt:
    mise exec -- python3 scripts/check-shell.py --fix
