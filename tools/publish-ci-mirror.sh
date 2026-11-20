#!/bin/sh
# Pushes the current HEAD to the public CI mirror without private packs and without private history.
# Usage: tools/publish-ci-mirror.sh [owner/repo]
set -eu
REPO="${1:-astronomytest01-rgb/recall-ci}"
EMAIL="240680395+astronomytest01-rgb@users.noreply.github.com"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git archive HEAD | tar -x -C "$TMP"
# Only the neutral starter pack goes public.
find "$TMP/Recall/Packs" -name '*.json' ! -name 'recall-guide.json' -delete
if grep -rqiE --exclude=publish-ci-mirror.sh 'favbet|allwin|kazik' "$TMP"; then
  echo "private mentions found, aborting:"; grep -rliE --exclude=publish-ci-mirror.sh 'favbet|allwin|kazik' "$TMP"; exit 1
fi
cd "$TMP"
git init -q -b main
git add -A
git -c user.name="Recall CI" -c user.email="$EMAIL" commit -q -m "Recall snapshot $(date -u +%Y-%m-%dT%H:%MZ)"
git push -q --force "https://github.com/$REPO.git" main
echo "pushed to $REPO"
