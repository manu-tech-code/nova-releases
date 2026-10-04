#!/bin/bash
# Installs, or updates, Nova from its latest release (the copy of this script in manu-tech-code/nova-releases):
#
#   curl -fsSL https://raw.githubusercontent.com/manu-tech-code/nova-releases/HEAD/install.sh | bash
#
# It reads the release feed the app's updater uses, downloads the .dmg with curl, checks that the app inside is
# signed by Nova's certificate, copies it to Applications and opens it. Files fetched with curl aren't marked as
# downloaded from the internet, so macOS doesn't block the first launch the way it does a browser download. From
# then on Nova updates itself (Check for Updates… in its menu). Everything of yours stays in ~/.nova.
#
# Options, as environment variables:
#   NOVA_INSTALL_DIR=<folder>   install there (default /Applications, or ~/Applications if that isn't writable)
#   NOVA_NO_OPEN=1              don't open Nova afterwards
set -euo pipefail

REPO="manu-tech-code/nova-releases"
FEED="https://github.com/$REPO/releases/latest/download/appcast.xml"
APP_NAME="Nova.app"
BUNDLE_ID="dev.nova.app"
TEAM_ID="KNK4UH42NN"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Nova is a Mac app."
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] || fail "Nova needs an Apple silicon Mac (M1 or later)."
MACOS=$(sw_vers -productVersion)
[ "${MACOS%%.*}" -ge 14 ] || fail "Nova needs macOS 14 or later; this Mac has macOS $MACOS."

DEST="${NOVA_INSTALL_DIR:-/Applications}"
if [ -z "${NOVA_INSTALL_DIR:-}" ] && [ ! -w "$DEST" ]; then DEST="$HOME/Applications"; fi
mkdir -p "$DEST" 2>/dev/null || true
[ -w "$DEST" ] || fail "Can't write to $DEST."
TARGET="$DEST/$APP_NAME"

WORK=$(mktemp -d -t nova)
MOUNT="$WORK/volume"
cleanup() {
  hdiutil detach "$MOUNT" -quiet -force >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

say "Finding the latest release"
APPCAST=$(curl -fsSL "$FEED") || fail "Couldn't reach GitHub."
VERSION=$(printf '%s\n' "$APPCAST" | sed -n 's|.*<sparkle:shortVersionString>\([^<]*\)<.*|\1|p' | head -n 1)
DMG_URL=$(printf '%s\n' "$APPCAST" | sed -n 's|.*<enclosure url="\([^"]*\)".*|\1|p' | head -n 1)
[ -n "$VERSION" ] && [ -n "$DMG_URL" ] || fail "The release feed doesn't list a download."
case "$DMG_URL" in
  "https://github.com/$REPO/releases/download/"*) ;;
  *) fail "Unexpected download address: $DMG_URL" ;;
esac

say "Downloading Nova $VERSION"
curl -fL --progress-bar -o "$WORK/Nova.dmg" "$DMG_URL" || fail "The download failed."

say "Checking the app's signature"
hdiutil attach "$WORK/Nova.dmg" -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" -quiet </dev/null || fail "Couldn't open the disk image."
SRC="$MOUNT/$APP_NAME"
[ -d "$SRC" ] || fail "The disk image doesn't contain $APP_NAME."
codesign --verify --deep --strict "$SRC" >/dev/null 2>&1 || fail "The app's signature isn't valid."
SIGNATURE=$(codesign -dv "$SRC" 2>&1)
printf '%s\n' "$SIGNATURE" | grep -qx "Identifier=$BUNDLE_ID" || fail "That isn't Nova ($BUNDLE_ID)."
printf '%s\n' "$SIGNATURE" | grep -qx "TeamIdentifier=$TEAM_ID" || fail "The app isn't signed by Nova's developer."

# Any Nova running - this copy, or a build from a checkout - is asked to quit: it stops its daemon first.
if pgrep -f "/$APP_NAME/Contents/MacOS/Nova\$" >/dev/null 2>&1; then
  say "Quitting the running Nova"
  pkill -TERM -f "/$APP_NAME/Contents/MacOS/Nova\$" || true
  for _ in $(seq 1 20); do
    pgrep -f "/$APP_NAME/Contents/MacOS/Nova\$" >/dev/null 2>&1 || break
    sleep 0.5
  done
fi

# A Nova.app built from a checkout (npm run app) elsewhere: moved to the Trash, so only one Nova opens at login.
for OTHER in "$HOME/Applications/$APP_NAME" "/Applications/$APP_NAME"; do
  [ "$OTHER" = "$TARGET" ] && continue
  if [ -f "$OTHER/Contents/Resources/shell.json" ] && ! grep -q '"@bundle"' "$OTHER/Contents/Resources/shell.json"; then
    say "Moving the build from your checkout ($OTHER) to the Trash"
    mv "$OTHER" "$HOME/.Trash/Nova (from a checkout) $(date +%s).app"
  fi
done

say "Installing in $DEST"
ditto "$SRC" "$WORK/$APP_NAME"
rm -rf "$TARGET"
mv "$WORK/$APP_NAME" "$TARGET"

say "Nova $VERSION is installed"
if [ -z "${NOVA_NO_OPEN:-}" ]; then
  open "$TARGET"
fi
