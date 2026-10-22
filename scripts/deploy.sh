#!/usr/bin/env bash
# Publish one stored solution package to one tenant, then deploy it (first time) or upgrade it in place.
# Runs in CI under an external app; no user token.
#
# Required env: ENV_NAME, VERSION, PKG_ZIP, UIP_TENANT, UIP_ORG, UIP_AUTHORITY,
#               UIP_CLIENT_ID, UIP_CLIENT_SECRET, UIP_SCOPES
set -euo pipefail

PACKAGE=CicdDemo
DEPLOYMENT="${PACKAGE}-${ENV_NAME}"
PARENT_FOLDER="${PARENT_FOLDER:-Shared}"

echo "::group::Login to ${UIP_ORG}/${UIP_TENANT} as external app"
uip login --authority "$UIP_AUTHORITY" --organization "$UIP_ORG" --tenant "$UIP_TENANT" \
  --client-id env.UIP_CLIENT_ID --client-secret env.UIP_CLIENT_SECRET \
  --scope "$UIP_SCOPES" --output json | jq '{Result, Code}'
uip login status --output json | jq '.Data | {Identity, IdentityType, Tenant}'
echo "::endgroup::"

echo "::group::Publish ${PACKAGE} ${VERSION} to the ${UIP_TENANT} tenant feed"
# Solution packages are per tenant feed, so the same zip is published once per tenant.
if ! out=$(uip solution publish "$PKG_ZIP" --wait --output json 2>&1); then
  if grep -qiE '409|already exists|conflict' <<<"$out"; then
    echo "Version ${VERSION} is already on this feed, continuing."
  else
    echo "$out"; exit 1
  fi
fi
echo "::endgroup::"

echo "::group::Deploy or upgrade ${DEPLOYMENT}"
key=$(uip solution deploy list --limit 200 --output json \
  --output-filter "[?Name=='${DEPLOYMENT}'].Key | [0]" | jq -r '.Data // empty')

if [[ -z "$key" ]]; then
  echo "No deployment named ${DEPLOYMENT} yet: creating it (deploy run, first time only)."
  uip solution deploy run --name "$DEPLOYMENT" \
    --package-name "$PACKAGE" --package-version "$VERSION" \
    --folder-name "$PACKAGE" --parent-folder-path "$PARENT_FOLDER" \
    --output json | tee deploy-result.json | jq '.Data | {Status, ActivationStatus, DeploymentKey}'
else
  echo "Deployment ${DEPLOYMENT} exists (${key}): upgrading in place to ${VERSION}."
  uip solution deploy upgrade "$key" --version "$VERSION" \
    --output json | tee deploy-result.json | jq '.Data | {Status, Operation, FromVersion, ToVersion, ActivationStatus}'
fi

jq -e '.Result == "Success"' deploy-result.json >/dev/null
echo "::endgroup::"

{
  echo "### ${ENV_NAME^^}: ${PACKAGE} ${VERSION}"
  echo ""
  echo "| Field | Value |"
  echo "| --- | --- |"
  jq -r '.Data | to_entries[] | select(.value|type=="string") | "| \(.key) | \(.value) |"' deploy-result.json
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
