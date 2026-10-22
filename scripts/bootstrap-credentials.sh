#!/usr/bin/env bash
# One-time, run by an org admin on their own machine (needs `uip login` as a user and `gh auth login`).
# Creates one confidential external app per environment tier and stores its credentials
# as GitHub *environment* secrets. Secrets go straight from uip to gh over stdin; they are never printed.
#
# Usage: scripts/bootstrap-credentials.sh <owner/repo>
set -euo pipefail

REPO="$1"
SCOPES="OR.Folders,OR.Execution,OR.Jobs,OR.Robots,OR.Machines,AutomationSolutions,Solutions.Deployments,Solutions.Deployments.Read,Solutions.Deployments.Write,Solutions.Packages,Solutions.Packages.Read,Solutions.Packages.Write,PM.Group,PM.Group.Read,RCS.FolderAuthorization"

for env in dev test prod; do
  app="cicd-$env"
  if uip admin external-apps list --output json | jq -e --arg n "$app" '.Data[] | select(.Name == $n)' >/dev/null; then
    echo "$app already exists, skipping (rotate its secret with generate-secret if you need a new one)."
    continue
  fi
  json=$(uip admin external-apps create "$app" --app-scope "$SCOPES" --output json)
  id=$(jq -r '.Data | .Id // .id // .ClientId // empty' <<<"$json")
  secret=$(jq -r '.Data | .Secret // .secret // .ClientSecret // empty' <<<"$json")
  [[ -n "$id" && -n "$secret" ]] || { echo "Could not read id/secret for $app:"; jq 'del(.. | .Secret?, .secret?, .ClientSecret?)' <<<"$json"; exit 1; }

  printf %s "$id"     | gh secret set UIP_CLIENT_ID     --repo "$REPO" --env "$env"
  printf %s "$secret" | gh secret set UIP_CLIENT_SECRET --repo "$REPO" --env "$env"
  unset secret json
  echo "$app created (client id $id) and stored in the '$env' environment of $REPO."
done
