#!/bin/sh
# Upload dSYM-mapper til Sentry efter Release-build (fx Archive).
# Kræver: brew install sentry-cli og SENTRY_* i Secrets.xcconfig (via DeveloperSettings).

set -u

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  echo "warning: DWARF_DSYM_FOLDER_PATH mangler — springer Sentry dSYM-upload over."
  exit 0
fi

if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
  echo "note: SENTRY_AUTH_TOKEN ikke sat — springer Sentry dSYM-upload over (valgfrit; tilføj i Secrets.xcconfig)."
  exit 0
fi

if [ -z "${SENTRY_ORG:-}" ] || [ -z "${SENTRY_PROJECT:-}" ]; then
  echo "warning: SENTRY_ORG eller SENTRY_PROJECT mangler — springer Sentry dSYM-upload over."
  exit 0
fi

if ! command -v sentry-cli >/dev/null 2>&1; then
  echo "warning: sentry-cli ikke i PATH — installer med: brew install sentry-cli"
  exit 0
fi

export SENTRY_AUTH_TOKEN
export SENTRY_ORG
export SENTRY_PROJECT

if ! sentry-cli debug-files upload "$DWARF_DSYM_FOLDER_PATH" 2>&1; then
  echo "warning: sentry-cli debug-files upload fejlede (tjek token og netværk)."
fi
exit 0
