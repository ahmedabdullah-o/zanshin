#!/bin/sh
# Fails the build/CI if a real Apple DEVELOPMENT_TEAM is committed to the pbxproj.
# This guards against accidentally pushing a personal Apple Developer Team ID.
#
# To use locally: sh scripts/check-no-team-id.sh
# In CI: same command, non-zero exit blocks the PR.

set -e

Pbxproj="Zanshin.xcodeproj/project.pbxproj"

if [ ! -f "$Pbxproj" ]; then
  echo "error: $Pbxproj not found"
  exit 1
fi

# Match DEVELOPMENT_TEAM = <non-empty value>
if grep -E '^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*"[^"]+"' "$Pbxproj"; then
  echo ""
  echo "error: a non-empty DEVELOPMENT_TEAM was found in $Pbxproj."
  echo "       Open the file and set DEVELOPMENT_TEAM = \"\" before committing."
  echo "       Each contributor must use their own Apple Developer Team in Xcode."
  exit 1
fi

# Also catch any 10-character alphanumeric Apple team ID that might appear
# elsewhere in the project (e.g. embedded in entitlements or xcconfig).
if grep -rE '\b[A-Z0-9]{10}\b' "$Pbxproj" \
     Zanshin.xcodeproj/ 2>/dev/null | grep -v '^Binary' | grep -v '/xcuserdata/'; then
  echo ""
  echo "warning: a 10-char token that looks like an Apple Team ID was found above."
  echo "         Please review and confirm it is not a Team ID."
  exit 1
fi

echo "ok: no DEVELOPMENT_TEAM leaked into the pbxproj"
