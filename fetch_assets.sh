#!/usr/bin/env bash
# Sync cooked GLBs from the asset server into assets/meshes/.
# The asset server (srv) is the source of truth; fetched files are
# .gitignore'd. Usage: ./fetch_assets.sh [pack_substring ...]
# With no args, fetches the packs Wayfarer currently uses.
set -euo pipefail

SERVER="${ASSET_SERVER:-http://srv.blastedstudios.com:49200}"
DEST="assets/meshes"

DEFAULT_PACKS=(
	POLYGON_Fantasy_Characters
	ANIMATION_Base_Locomotion
	POLYGON_Fantasy_Kingdom
	POLYGON_NatureBiomes_MeadowForest
)

PACKS=("${@:-${DEFAULT_PACKS[@]}}")

index=$(curl -fsS --max-time 30 "$SERVER/index.json")

for pack in "${PACKS[@]}"; do
	echo "== $pack"
	echo "$index" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for p in d['cooked']['packs']:
    if '$pack'.lower() in p['name'].lower():
        for f in p['files']:
            if f['path'].endswith(('.glb', '.png')):
                print(f['path'])
" | while IFS= read -r path; do
		out="$DEST/${path#assets/}"
		if [[ -f "$out" ]]; then
			continue
		fi
		mkdir -p "$(dirname "$out")"
		curl -fsS --max-time 60 -o "$out" "$SERVER/$path"
		echo "  fetched ${path#assets/}"
	done
done
echo "Done. Run: godot --headless --import"
