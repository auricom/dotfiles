#!/usr/bin/fish
type fisher &>/dev/null || curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
fisher install decors/fish-colored-man
fisher install evanlucas/fish-kubectl-completions
fisher install franciscolourenco/done
fisher install jethrokuan/z
fisher install patrickf3139/fzf.fish
fisher install wfxr/forgit

