#!/usr/bin/env bash
set -euo pipefail

# Usage: ./update.sh /path/to/support-events.json
# Copies the given JSON, zips it, updates manifest.json with new SHA256 hashes.

SRC="${1:?Usage: $0 <path-to-support-events.json>}"
SRC="$(realpath "$SRC")"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "updating from $SRC"

# content hash — this is the real change detector
SHA256_JSON=$(sha256sum "$SRC" | cut -d' ' -f1)

# read previous manifest state
PREV_SHA256_JSON=$(jq -r '.files[] | select(.id == "support-events") | .sha256_json' manifest.json 2>/dev/null || echo "")
PREV_MANIFEST_VER=$(jq -r '.version' manifest.json 2>/dev/null || echo 0)
PREV_EVENTS_VER=$(jq -r '.files[] | select(.id == "support-events") | .version' manifest.json 2>/dev/null || echo 0)

# only bump versions when content actually changed
if [ "$SHA256_JSON" = "$PREV_SHA256_JSON" ]; then
  MANIFEST_VERSION=$PREV_MANIFEST_VER
  EVENTS_VERSION=$PREV_EVENTS_VER
  echo "content unchanged — keeping versions ($MANIFEST_VERSION / $EVENTS_VERSION)"
else
  MANIFEST_VERSION=$((PREV_MANIFEST_VER + 1))
  EVENTS_VERSION=$((PREV_EVENTS_VER + 1))
  echo "content changed — bumping versions ($MANIFEST_VERSION / $EVENTS_VERSION)"
fi

# copy, zip, hash
cp "$SRC" support-events.json
zip -f support-events.json.zip support-events.json 2>/dev/null ||
  zip support-events.json.zip support-events.json
rm support-events.json

SHA256_ZIP=$(sha256sum support-events.json.zip | cut -d' ' -f1)

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
      "sha256_zip": "$SHA256_ZIP",
      "sha256_json": "$SHA256_JSON",
      "version": $EVENTS_VERSION,
      "updated_at": "$NOW"
    }
  ]
}
EOF

echo "done — manifest_version=$MANIFEST_VERSION support_events_version=$EVENTS_VERSION sha256_json=$SHA256_JSON sha256_zip=$SHA256_ZIP"
