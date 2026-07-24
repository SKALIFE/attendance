#!/bin/bash
set -euo pipefail

PROFILE="skala-notary"
DMG="release/SKALA-Attendance-0.1.0-arm64.dmg"
APPLE_ID="dayeon.dev@gmail.com"
TEAM_ID="9XY8538U7T"

echo "=== SKALA Attendance Notarization ==="
echo ""

# Step 1: Check if credentials are stored
if ! xcrun notarytool history --keychain-profile "$PROFILE" &>/dev/null; then
    echo "App-specific password is needed."
    echo "If you don't have one, create it at:"
    echo "  https://appleid.apple.com → Sign In → App-Specific Passwords → Generate"
    echo ""
    echo "Enter your app-specific password when prompted:"
    xcrun notarytool store-credentials "$PROFILE" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID"
    echo ""
    echo "Credentials stored successfully."
fi

# Step 2: Submit DMG for notarization
echo ""
echo "=== Submitting DMG to Apple ==="
SUBMISSION=$(xcrun notarytool submit \
    --keychain-profile "$PROFILE" \
    "$DMG" --json 2>/dev/null)

SUBMISSION_ID=$(echo "$SUBMISSION" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "unknown")
echo "Submission ID: $SUBMISSION_ID"

# Step 3: Wait for completion
echo ""
echo "=== Waiting for notarization (this can take 2-10 minutes) ==="
xcrun notarytool wait "$SUBMISSION_ID" \
    --keychain-profile "$PROFILE"

# Step 4: Staple
echo ""
echo "=== Stapling ticket to DMG ==="
xcrun stapler staple "$DMG"

# Step 5: Verify
echo ""
echo "=== Verification ==="
spctl --assess --verbose=4 "$DMG" 2>&1
xcrun stapler validate "$DMG"

echo ""
echo "=== Notarization complete! ==="
echo "The DMG will now open without Gatekeeper warnings."
