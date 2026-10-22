#!/usr/bin/env bash
# Usage: open-promotion-pr.sh <record-env|""> <target-env> <version>
# 1. If <record-env> is set, write <version> into environments/<record-env>.yaml on main
#    (the pipeline already deployed it there).
# 2. Open a PR that changes environments/<target-env>.yaml to <version>. Merging it deploys.
set -euo pipefail

record_env="$1"; target_env="$2"; version="$3"
set_version() { sed -i -E "s/(version: )\"[^\"]+\"/\1\"$2\"/" "environments/$1.yaml"; }

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
push() { for i in 1 2 3; do git push origin "$@" && return 0; echo "push failed, retry $i"; sleep $((i * 5)); done; return 1; }

# Start from the newest main, so a rerun after a partial failure does not conflict.
git fetch -q origin main && git checkout -q -B main origin/main

if [[ -n "$record_env" ]]; then
  set_version "$record_env" "$version"
  if ! git diff --quiet; then
    git commit -qam "Record CicdDemo $version on ${record_env^^}"
    push HEAD:main
  fi
fi

branch="promote/${target_env}-${version}"
if gh pr list --head "$branch" --state open --json number --jq '.[0].number' | grep -q .; then
  echo "PR for $branch is already open."; exit 0
fi
git switch -C "$branch"
set_version "$target_env" "$version"
git commit -qam "Promote CicdDemo $version to ${target_env^^}"
push --force "$branch"

gh label create "promote:${target_env}" --color "1d76db" --force >/dev/null
gh pr create --base main --head "$branch" --label "promote:${target_env}" \
  --title "Promote CicdDemo $version to ${target_env^^}" \
  --body "$(cat <<EOF
Changes one line in \`environments/${target_env}.yaml\` to \`$version\`.

Merging this PR publishes the stored package [cicddemo-v$version](../releases/tag/cicddemo-v$version) to the **${target_env^^}** tenant and upgrades the deployment in place. Nothing is rebuilt.
EOF
)"
