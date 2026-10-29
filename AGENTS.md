# AGENTS.md

A SekaiPop plugin (QML + one `.pragma library` JS file), not built by hajime: there is no QML
stack there. Same shape as `masshirodev/sekaipop-kumiko`.

- **The plugin interface is SekaiPop's `docs/PLUGINS.md`** (desktop widget, bar entry, popup,
  service). A plugin can't import the shell's `qs.*` modules; `host` and the manifest are all it
  gets. Use only the theme names that file promises.
- **Rules go in `tailscale/lib/Tailscale.js`**, tested in node (`scripts/test.sh`, 95 % lines,
  branches and functions, never lowered). QML draws what it returns and holds no logic of its own.
- **`doc/DESIGN.md` records every departure from the handoff** (`doc/briefs/handoff-tailscale/`).
  Add to it when you depart again.
- **Check QML by running it**: `/usr/lib/qt6/bin/qmllint` (not `/usr/bin/qmllint`, which is
  Qt 5's and passes anything), then a live shell; `doc/DESIGN.md`, "Checking it", has the
  isolated second-shell recipe and the fake `tailscale` for the other states.
- `tailscale status --json` is read-only and needs no root. Never run `tailscale up`, `down`,
  `set` or `logout` from here: they change the owner's network.
- Board: the `sekaipop` board in Lattice (this repo's cards are there).
- Push to `main`.
