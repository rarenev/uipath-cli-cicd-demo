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

if [[ -n "$record_env" ]]; then
  set_version "$record_env" "$version"
  git commit -am "Record CicdDemo $version on ${record_env^^}"
  git push origin HEAD:main
fi

branch="promote/${target_env}-${version}"
git switch -c "$branch"
set_version "$target_env" "$version"
git commit -am "Promote CicdDemo $version to ${target_env^^}"
git push origin "$branch"

gh label create "promote:${target_env}" --color "1d76db" --force >/dev/null
gh pr create --base main --head "$branch" --label "promote:${target_env}" \
  --title "Promote CicdDemo $version to ${target_env^^}" \
  --body "$(cat <<EOF
Changes one line in \`environments/${target_env}.yaml\` to \`$version\`.

Merging this PR publishes the stored package [cicddemo-v$version](../releases/tag/cicddemo-v$version) to the **${target_env^^}** tenant and upgrades the deployment in place. Nothing is rebuilt.
EOF
)"
