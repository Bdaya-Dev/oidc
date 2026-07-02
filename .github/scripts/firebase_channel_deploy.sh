#!/usr/bin/env bash
# Deploy one Firebase Hosting preview channel with honest error classification.
#
# Why not FirebaseExtended/action-hosting-deploy: firebase-tools' apiv2 client
# retries POSTs after transient "premature close" network errors even though
# the channel-release POST is not idempotent. The first POST usually succeeds
# server-side, so the retry gets HTTP 400 FAILED_PRECONDITION ("supplied
# version ... is the current active version"). The action treats that as a
# hard failure and, when given a repoToken, writes a failing "Deploy Preview"
# check-run onto the PR even when the job is green. Here that error means
# "the content is already live" and is classified as success; anything else
# fails the step for real (no blanket continue-on-error).
#
# Inputs (env): FIREBASE_SERVICE_ACCOUNT, PROJECT_ID, TARGET, CHANNEL
# Outputs (GITHUB_OUTPUT): url=<stable channel URL>
set -uo pipefail

: "${FIREBASE_SERVICE_ACCOUNT:?}" "${PROJECT_ID:?}" "${TARGET:?}" "${CHANNEL:?}"

export GOOGLE_APPLICATION_CREDENTIALS="${RUNNER_TEMP}/firebase-sa-${TARGET}.json"
printf '%s' "$FIREBASE_SERVICE_ACCOUNT" > "$GOOGLE_APPLICATION_CREDENTIALS"
trap 'rm -f "$GOOGLE_APPLICATION_CREDENTIALS"' EXIT

FIREBASE="npx --yes firebase-tools@15"

set +e
out="$($FIREBASE hosting:channel:deploy "$CHANNEL" \
  --only "$TARGET" --expires 7d --project "$PROJECT_ID" --json 2>&1)"
code=$?
set -e
echo "$out"

if [ "$code" -ne 0 ]; then
  if grep -q "is the current active version" <<<"$out"; then
    echo "::notice title=Redundant release::${TARGET}/${CHANNEL}: content already live; treating as success."
  else
    echo "::error title=Firebase preview deploy failed::target=${TARGET} channel=${CHANNEL}"
    exit 1
  fi
fi

# Channel URLs are stable per channel (https://<site>--<channel>-<hash>.web.app).
# Take it from the deploy output; on the redundant-release path fall back to
# the channel list.
url="$(grep -oE "https://[A-Za-z0-9-]+\.web\.app" <<<"$out" | grep -- "--${CHANNEL}-" | head -1 || true)"
if [ -z "$url" ]; then
  list_out="$($FIREBASE hosting:channel:list --site "$TARGET" --project "$PROJECT_ID" 2>&1 || true)"
  url="$(grep -oE "https://[A-Za-z0-9-]+\.web\.app" <<<"$list_out" | grep -- "--${CHANNEL}-" | head -1 || true)"
fi

echo "url=${url}" >> "$GITHUB_OUTPUT"
{
  echo "### Firebase preview: \`${TARGET}\`"
  if [ -n "$url" ]; then echo "${url} (expires 7d after last deploy)"; else echo "_deployed, but URL could not be determined_"; fi
} >> "$GITHUB_STEP_SUMMARY"
