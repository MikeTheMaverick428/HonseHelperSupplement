#!/usr/bin/env bash
set -euo pipefail

# Usage: ./update.sh /path/to/support-events.json /path/to/character-events.json
# Copies the given JSON files, zips them, updates manifest.json with new SHA256 hashes.

SRC_SUPPORT="${1:?Usage: $0 <path-to-support-events.json> <path-to-character-events.json>}"
SRC_CHAR="${2:?Usage: $0 <path-to-support-events.json> <path-to-character-events.json>}"
SRC_SUPPORT="$(realpath "$SRC_SUPPORT")"
SRC_CHAR="$(realpath "$SRC_CHAR")"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "updating from $SRC_SUPPORT and $SRC_CHAR"

# read previous manifest state
PREV_MANIFEST_VER=$(jq -r '.version' manifest.json 2>/dev/null || echo 0)

# ---------- support-events ----------
SHA256_JSON_SUPPORT=$(sha256sum "$SRC_SUPPORT" | cut -d' ' -f1)
PREV_SHA256_SUPPORT=$(jq -r '.files[] | select(.id == "support-events") | .sha256_json' manifest.json 2>/dev/null || echo "")
PREV_VER_SUPPORT=$(jq -r '.files[] | select(.id == "support-events") | .version' manifest.json 2>/dev/null || echo 0)

if [ "$SHA256_JSON_SUPPORT" = "$PREV_SHA256_SUPPORT" ]; then
  VER_SUPPORT=$PREV_VER_SUPPORT
  echo "support-events: unchanged — keeping version $VER_SUPPORT"
else
  VER_SUPPORT=$((PREV_VER_SUPPORT + 1))
  echo "support-events: changed — bumping to version $VER_SUPPORT"
fi

cp "$SRC_SUPPORT" support-events.json
zip -f support-events.json.zip support-events.json 2>/dev/null ||
  zip support-events.json.zip support-events.json
rm support-events.json
SHA256_ZIP_SUPPORT=$(sha256sum support-events.json.zip | cut -d' ' -f1)

# ---------- character-events ----------
SHA256_JSON_CHAR=$(sha256sum "$SRC_CHAR" | cut -d' ' -f1)
PREV_SHA256_CHAR=$(jq -r '.files[] | select(.id == "character-events") | .sha256_json' manifest.json 2>/dev/null || echo "")
PREV_VER_CHAR=$(jq -r '.files[] | select(.id == "character-events") | .version' manifest.json 2>/dev/null || echo 0)

if [ "$SHA256_JSON_CHAR" = "$PREV_SHA256_CHAR" ]; then
  VER_CHAR=$PREV_VER_CHAR
  echo "character-events: unchanged — keeping version $VER_CHAR"
else
  VER_CHAR=$((PREV_VER_CHAR + 1))
  echo "character-events: changed — bumping to version $VER_CHAR"
fi

cp "$SRC_CHAR" character-events.json
zip -f character-events.json.zip character-events.json 2>/dev/null ||
  zip character-events.json.zip character-events.json
rm character-events.json
SHA256_ZIP_CHAR=$(sha256sum character-events.json.zip | cut -d' ' -f1)

# ---------- manifest version ----------
CHANGED=0
[ "$SHA256_JSON_SUPPORT" != "$PREV_SHA256_SUPPORT" ] && CHANGED=1
[ "$SHA256_JSON_CHAR" != "$PREV_SHA256_CHAR" ] && CHANGED=1

if [ "$CHANGED" -eq 1 ]; then
  MANIFEST_VERSION=$((PREV_MANIFEST_VER + 1))
else
  MANIFEST_VERSION=$PREV_MANIFEST_VER
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)

cat > manifest.json <<EOF
{
  "version": $MANIFEST_VERSION,
  "updated_at": "$NOW",
  "files": [
    {
      "id": "support-events",
      "filename": "support-events.json",
      "zip_filename": "support-events.json.zip",
      "sha256_zip": "$SHA256_ZIP_SUPPORT",
      "sha256_json": "$SHA256_JSON_SUPPORT",
      "version": $VER_SUPPORT,
      "updated_at": "$NOW"
    },
    {
      "id": "character-events",
      "filename": "character-events.json",
      "zip_filename": "character-events.json.zip",
      "sha256_zip": "$SHA256_ZIP_CHAR",
      "sha256_json": "$SHA256_JSON_CHAR",
      "version": $VER_CHAR,
      "updated_at": "$NOW"
    }
  ]
}
EOF

echo "done — manifest_version=$MANIFEST_VERSION support_events_version=$VER_SUPPORT character_events_version=$VER_CHAR"
