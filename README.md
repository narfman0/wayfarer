# Wayfarer

A cosmic fantasy RPG about two companions wandering between planes of existence.

**Status:** Playable prototype — all three acts start-to-finish (two endings), plus a procedural dungeon side-mode

## Getting Started

Prerequisites: [Godot 4.7.1](https://godotengine.org/download) on your PATH, plus access to the Blasted Studios asset server for meshes/textures.

```bash
# 1. Clone with the SRD rules-engine submodule
git clone --recurse-submodules https://github.com/narfman0/wayfarer.git
cd wayfarer
# (already cloned? run: git submodule update --init --recursive)

# 2. Fetch cooked art assets (gitignored; asset server is the source of truth)
./fetch_assets.sh          # only what the project references + deps (~50 MB)
                           # override server with ASSET_SERVER=http://host:port

# 3. Import assets
godot --headless --import

# 4. Play (or open the project in the Godot editor)
godot
```

Notes:

- The SRD ruleset is consumed via a committed symlink `addons/srd -> ../vendor/godot-srd-addon/addons/srd`. Don't copy the addon repo into `addons/` directly — the symlink is the supported layout. On Windows, enable git symlinks (`git config core.symlinks true` + Developer Mode) before cloning.
- `./fetch_assets.sh` (default) fetches only the assets the project actually references — resolved from `ext_resource` paths, `scenery.gd`'s `pack:Name` vocab, and the animation clip constants — plus each glTF's `.bin` and textures. It skips files you already have, so re-run it any time. Adding packs to the asset server costs nothing locally until a scene/script references one of their assets.
- To browse a whole pack you're about to author with, use `./fetch_assets.sh --pack <substr> …` (no substrings = the default pack set). Once you've referenced the assets you want, the default used-only fetch keeps exactly those.

## Docs

- [Architecture & current state](docs/architecture.md) — **start here**: what's actually built
- [Design docs](docs/design/) — gameplay, levels, bosses, progression, classes
- [Narrative docs](docs/narrative/) — setting bible, act-by-act beats

## Testing

Headless smoke suites live in `future/tests/harnesses/` — each prints
`ALL PASS` and exits nonzero on failure:

```bash
godot --headless res://future/tests/harnesses/systems_smoke.tscn   # or any suite
```

Visual review: `xvfb-run -a godot --rendering-driver opengl3 res://future/tests/harnesses/plane_gallery.tscn` screenshots every plane to `.screenshots/`.

## Quick Summary

Two companions follow the trail of unintended damage left by well-meaning antagonists destabilizing the Veil — a network of portals connecting planes of existence. Locked isometric camera, sword-and-skill combat that runs real-time by default with an opt-in BG3-style turn-based mode, full D&D-style character building (classes, species, feats, subclasses, spells), and a gold/loot economy. Tone: *Blade of the Immortal* meets *Planescape*.

Engine: Godot 4 | Rules: Custom SRD-compatible fantasy ruleset (git submodule)
