# Wayfarer

A cosmic fantasy RPG about two companions wandering between planes of existence.

**Status:** Pre-production — design docs + playable Act 1 prototype

## Getting Started

Prerequisites: [Godot 4.7.1](https://godotengine.org/download) on your PATH, plus access to the Blasted Studios asset server for meshes/textures.

```bash
# 1. Clone with the SRD rules-engine submodule
git clone --recurse-submodules https://github.com/narfman0/wayfarer.git
cd wayfarer
# (already cloned? run: git submodule update --init --recursive)

# 2. Fetch cooked art assets (gitignored; asset server is the source of truth)
./fetch_assets.sh          # override server with ASSET_SERVER=http://host:port

# 3. Import assets
godot --headless --import

# 4. Play (or open the project in the Godot editor)
godot
```

Notes:

- The SRD ruleset is consumed via a committed symlink `addons/srd -> ../vendor/godot-srd-addon/addons/srd`. Don't copy the addon repo into `addons/` directly — the symlink is the supported layout. On Windows, enable git symlinks (`git config core.symlinks true` + Developer Mode) before cloning.
- Re-run `./fetch_assets.sh` any time new packs are added; it only downloads files you don't already have.

## Docs

- [Setting Bible](docs/setting.md) — world, companions, antagonist, planes

## Quick Summary

Two companions follow the trail of unintended damage left by an antagonist destabilizing the Veil — a network of portals connecting planes of existence. The game is slow, thoughtful, sword-and-skill combat, no crafting, real-time-with-pause. Tone: *Blade of the Immortal* meets *Planescape*.

Engine: Godot 4 | Rules: Custom SRD-compatible space fantasy ruleset
