# Repository instructions

This is a chezmoi source repository. Read the shared helpers and script header
comments before changing shell scripts. Reuse existing helpers and nearby patterns.
Use shell for repository scripts; do not add Python scripts.

## Shell presentation

- Every `.chezmoiscripts/*.sh.tmpl` lifecycle script must include
  `.chezmoitemplates/script-header`, define `main()`, and include
  `.chezmoitemplates/script-footer` inside its profile condition, if any.
  The header loads `dot_local/lib/chezmoi_utils.sh` and the shared error trap.
  Keep operations idempotent and skip optional interactive setup without a terminal.
- Operational commands in `dot_local/bin/` use Bash, `set -Eeuo pipefail`,
  four-space indentation, `common_utils.sh`, the `report_error` ERR trap,
  and a final `main "$@"` entry point.
  Commands that explicitly opt into `notifications.sh` may use its `notify_error`
  trap, which also calls the shared error reporter.
- Use `log_section`, `log_info`, `log_warn`, `log_error`, `log_debug`, and
  `run_spin` for human-facing progress and diagnostics. Use `confirm` and
  `prompt_input` for interaction. Do not call gum directly or invent formatting;
  `dot_local/lib/common_utils.sh.tmpl` owns Gum, terminal colors, and plain output.
- Keep diagnostics on stderr and pipeable data on stdout. Plain `printf`/`echo`
  remain appropriate for data, generated configuration, and help output.
- Commands with options provide `--help` and return status 2 for invalid usage
  before dependencies or side effects. Use `require_no_args` for commands without options.
- Confirmation defaults to no: handle status 0 (yes), 1 (no), and greater than 1
  (unavailable or interrupted) explicitly. Input requires terminal stdin and stderr.
- Keep script-specific usage and operational notes in script header comments.
- POSIX prompt-data utilities (`github-icon`, `fishfy-path`,
  `relative-time-commit`) and transparent launchers (`1password`, `recur-app`)
  are exceptions to the operational framework. Keep their output contracts.
  The `terminal-theme` background hook uses shared diagnostics but stays silent
  on success.

## Verification

- Run `bash scripts/check-script-style.sh` after changing scripts. Lefthook
  also runs this check before commits. Keep this check and the documented
  exceptions in sync.
- Render changed chezmoi templates with `chezmoi execute-template` before
  running `bash -n`, ShellCheck, or shfmt on them. Check affected workstation
  and server branches; never pass unrendered Go templates to shell tooling.
- Run focused checks with temporary fixtures or mocked external commands.
  Do not run unrelated lifecycle operations, installs, or service restarts
  just to verify formatting. Preserve existing local changes.
