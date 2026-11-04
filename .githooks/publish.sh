#!/bin/sh
# One-command publish: stage everything allowed, commit, push.
# Usage:  git pub "area: what changed"
#
# Safety comes from two saves, not from this script:
#   .gitignore        - keeps secrets/logs/dev tree untracked
#   .githooks/pre-commit - refuses forbidden paths and secret patterns
# So `git add -A` here cannot publish anything outside the whitelist.
set -eu

msg=${1:-}
if [ -z "$msg" ]; then
    echo 'usage: git pub "area: what changed"' >&2
    exit 1
fi

git add -A
if git diff --cached --quiet; then
    echo "nothing to commit" >&2
    exit 0
fi

git commit -m "$msg"
git push -u origin HEAD
