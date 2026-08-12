#!/usr/bin/env bash
# Sync cooked meshes/textures from the asset server into assets/meshes/.
# The asset server (srv) is the source of truth; fetched files are .gitignore'd.
#
# Two modes:
#   ./fetch_assets.sh                 # DEFAULT: fetch only what the project
#                                     #   references, plus each glTF's .bin +
#                                     #   textures. ~50 MB, not the full ~1 GB.
#   ./fetch_assets.sh --pack egypt …  # whole-pack fetch (for browsing a pack
#                                     #   you're about to author with). No args
#                                     #   after --pack = the DEFAULT_PACKS set.
#
# Why "used-only" is safe: nothing in the project loads meshes by directory
# scan — every asset is referenced by an ext_resource path, a scenery.gd
# "pack:Name" vocab entry, or an explicit animation path. The resolver below
# covers all three, so a fresh clone gets exactly the working set. Add packs to
# the server freely; they cost nothing here until a scene/script references them.
set -euo pipefail

SERVER="${ASSET_SERVER:-http://srv.blastedstudios.com:49200}"
DEST="assets/meshes"

DEFAULT_PACKS=(
	_skies
	POLYGON_Fantasy_Characters
	ANIMATION_Base_Locomotion
	POLYGON_Fantasy_Kingdom
	POLYGON_NatureBiomes_MeadowForest
	POLYGON_AncientEgypt
	POLYGON_Scifi_Space
	POLYGON_Western_Pack
	POLYGON_Prototype
)

# ── whole-pack mode (legacy) ──────────────────────────────────────────────────
if [[ "${1:-}" == "--pack" || "${1:-}" == "--all" ]]; then
	shift
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
            if f['path'].endswith(('.glb', '.gltf', '.bin', '.png')):
                print(f['path'])
" | while IFS= read -r path; do
			out="$DEST/${path#assets/}"
			[[ -f "$out" ]] && continue
			mkdir -p "$(dirname "$out")"
			curl -fsS --max-time 60 -o "$out" "$SERVER/$path"
			echo "  fetched ${path#assets/}"
		done
	done
	echo "Done. Run: godot --headless --import"
	exit 0
fi

# ── used-only mode (default): resolve the reference closure and fetch it ───────
SERVER="$SERVER" DEST="$DEST" python3 - <<'PYEOF'
import json, os, re, glob, sys, urllib.request, urllib.parse

SERVER = os.environ["SERVER"]
DEST   = os.environ["DEST"]           # local root: assets/meshes
LOCAL_PREFIX  = DEST + "/"            # local  path:  assets/meshes/<rest>
SERVER_PREFIX = "assets/"            # server path:  assets/<rest>

def local_to_server(fs):
    return SERVER_PREFIX + fs[len(LOCAL_PREFIX):]

def res_to_fs(p):
    return p.replace("res://", "", 1)

# 1) literal res://assets/meshes/....(gltf|glb|png) anywhere in the project
referenced = set()
for base in ("scenes", "scripts", "resources"):
    for f in glob.glob(base + "/**/*", recursive=True):
        if not os.path.isfile(f):
            continue
        txt = open(f, encoding="utf-8", errors="ignore").read()
        for m in re.findall(r'res://assets/meshes/[^"\'\s]+?\.(?:gltf|glb|png)', txt):
            referenced.add(res_to_fs(m))

# 2) scenery.gd "pack:Name" vocab — resolve via the PACKS registry parsed from
#    the same file so the two never drift.
scenery = open("scripts/world/scenery.gd").read()
packs = {}
for key, dir_, ext in re.findall(
        r'"(\w+)":\s*\{[^}]*?"dir":\s*"res://([^"]+)"[^}]*?"ext":\s*"([^"]+)"',
        scenery, re.S):
    packs[key] = (dir_, ext)
for pack, name in re.findall(r'"(\w+):([^"]+)"', scenery):
    if pack in packs:
        dir_, ext = packs[pack]
        referenced.add(dir_ + name + ext)

# 3) explicit animation clips ( _ANIM_ROOT + "…" ). Full-literal paths (e.g. the
#    reference character) are already caught by step 1.
src = open("scripts/world/character_animator.gd").read()
m = re.search(r'_ANIM_ROOT\s*:=\s*"res://([^"]+)"', src)
if m:
    root = m.group(1)
    for suffix in re.findall(r'_ANIM_ROOT\s*\+\s*"([^"]+)"', src):
        referenced.add(root + suffix)

# 4) dir-const + bare-filename pattern (dungeon_run's prop lists): any .gd
#    that defines a res://assets/meshes/... dir const gets its quoted
#    *.gltf/*.glb basenames resolved against every such const in the file.
for f in glob.glob("scripts/**/*.gd", recursive=True):
    txt = open(f, encoding="utf-8", errors="ignore").read()
    dirs = re.findall(r':=\s*"res://assets/meshes/([^"]+/)"', txt)
    if not dirs:
        continue
    for name in re.findall(r'"([A-Za-z0-9_]+\.(?:gltf|glb))"', txt):
        for d in dirs:
            referenced.add("assets/meshes/" + d + name)

# Resolve the dependency closure: each glTF pulls its .bin + texture images.
# .glb is self-contained. Fetch a glTF (small) to read its deps if absent.
closure = set()
_seen = set()

def http_get(server_path, out_fs):
    os.makedirs(os.path.dirname(out_fs), exist_ok=True)
    with urllib.request.urlopen(f"{SERVER}/{server_path}", timeout=60) as r:
        data = r.read()
    with open(out_fs, "wb") as fh:
        fh.write(data)

def ensure(fs):
    if fs in _seen:
        return
    _seen.add(fs)
    closure.add(fs)
    if not os.path.isfile(fs):
        try:
            http_get(local_to_server(fs), fs)
            print(f"  fetched {fs[len(LOCAL_PREFIX):]}")
        except Exception as e:
            print(f"  MISS {fs[len(LOCAL_PREFIX):]}  ({e})", file=sys.stderr)
            return
    if fs.endswith(".gltf"):
        try:
            d = json.load(open(fs))
        except Exception:
            return
        base = os.path.dirname(fs)
        for section in ("buffers", "images"):
            for item in d.get(section, []):
                uri = item.get("uri")
                if uri and not uri.startswith("data:"):
                    ensure(os.path.normpath(os.path.join(base, urllib.parse.unquote(uri))))

for r in sorted(referenced):
    ensure(r)

have = sum(1 for p in closure if os.path.isfile(p))
size = sum(os.path.getsize(p) for p in closure if os.path.isfile(p))
print(f"Reference closure: {have}/{len(closure)} files present, {size/1024/1024:.1f} MB.")
PYEOF
echo "Done. Run: godot --headless --import"

# Post-process: fix foliage gltf materials (BLEND→MASK, bad texture indices).
python3 "$(dirname "$0")/tools/patch_gltf_materials.py" 2>/dev/null || true
