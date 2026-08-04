#!/usr/bin/env python3
"""
Post-process cooked gltf files under assets/meshes/:
  1. alphaMode BLEND → MASK + alphaCutoff 0.5
     Foliage/plant gltfs export with BLEND, causing depth-sort artifacts in
     Godot's Forward+ renderer at isometric angles. MASK uses alpha-test
     instead (no sorting, binary transparency) which is correct for grass,
     bushes, flowers, and Synty billboard foliage in general.
  2. Out-of-bounds texture indices → clamped to the images array length.
     Some materials reference image index N when only N-1 images exist;
     Godot falls back to a default error material.

Run: python3 tools/patch_gltf_materials.py
Idempotent: skips files already patched. Deletes stale .gltf.import sidecars
for any file it modifies so Godot re-imports with correct materials.
"""
import json
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).parent.parent / "assets" / "meshes"
ALPHA_CUTOFF = 0.5


def patch_file(path: pathlib.Path) -> bool:
    with open(path) as f:
        g = json.load(f)

    images = g.get("images", [])
    max_idx = max(len(images) - 1, 0)
    changed = False

    for mat in g.get("materials", []):
        if mat.get("alphaMode") == "BLEND":
            mat["alphaMode"] = "MASK"
            mat.setdefault("alphaCutoff", ALPHA_CUTOFF)
            changed = True

        pbr = mat.get("pbrMetallicRoughness", {})
        bct = pbr.get("baseColorTexture")
        if bct is not None and bct.get("index", 0) > max_idx:
            bct["index"] = max_idx
            changed = True

    if not changed:
        return False

    with open(path, "w") as f:
        json.dump(g, f, separators=(",", ":"))

    sidecar = path.with_suffix(path.suffix + ".import")
    if sidecar.exists():
        sidecar.unlink()

    return True


def main():
    if not ROOT.exists():
        print(f"assets/meshes/ not found at {ROOT} — run fetch_assets.sh first")
        sys.exit(1)

    patched = 0
    for gltf in ROOT.rglob("*.gltf"):
        if patch_file(gltf):
            print(f"patched  {gltf.relative_to(ROOT)}")
            patched += 1

    print(f"\n{patched} file(s) patched.")


if __name__ == "__main__":
    main()
