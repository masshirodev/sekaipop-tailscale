# Design: from the handoff to the plugin

The handoff is `doc/briefs/handoff-tailscale/` (the Tailscale page of the shared SekaiPop canvas;
its notes ts1 to ts4 are the decisions). The brief is `doc/briefs/TAILSCALE.md`. This file says
how the design became the plugin, where it departs from it and why, and what it doesn't do yet.

## Shape

| File                       | What it is                                                                 |
| -------------------------- | -------------------------------------------------------------------------- |
| `tailscale/plugin.json`    | the manifest: `bar` (label, icon), the settings the handoff's Settings board lists |
| `tailscale/Service.qml`    | the one poller: `tailscale status --json` through `sh`, read by every surface (`host.service`) |
| `tailscale/Bar.qml`        | the entry's inside (the shell draws the pill)                              |
| `tailscale/Popup.qml`      | the popup's face, 354 wide (the 360 card less its outline, which the shell draws) |
| `tailscale/Widget.qml`     | the desktop widget, inside the shell's card frame: full (340, 374 with the frame) or compact (148, 182) |
| `tailscale/lib/Tailscale.js` | every rule, tested in node                                               |
| `tailscale/lib/*.qml`      | the parts: `Icon`, `Dot`, `WarnDiamond`, `KeyCap`, `StatusChip`, `HubBadge`, `DeviceRow`, `SectionHead`, `FoldRow`, `StateMessage` |

Colours: the bar entry and the popup use the theme's bar family (`surface`, `ink`, `line`, ...),
the widget the card family (`pSurface`, `pInk`, ...), as the handoff's note ts2 says. Each surface
builds one `pal` object of its family and hands it to the parts, so a part never guesses which.

## How it reads Tailscale

- `Service.qml` runs `sh -c 'command -v tailscale || echo <marker>; exec tailscale status --json 2>&1'`.
  stdout and stderr together go to `TS.model()`, which tells apart an answer (JSON with a
  `BackendState`), no daemon ("failed to connect to local tailscaled"), no command (the marker)
  and anything else (its first line, as the message).
- It runs only while something shows it: every 30 s for the bar alone, at "Check every" (default
  5 s) while the popup or the widget is up, and at once when the popup opens.
- The count is online peers over all peers; this machine is not counted. "Only mine" keeps the
  peers whose `UserID` is this machine's.

## Where it departs from the handoff, and why

- **"Via relay" only while traffic flows** (`Active`, a `Relay`, no `CurAddr`). The handoff says
  "reached through DERP (Relay set, CurAddr empty)", but an idle device has no `CurAddr` either and
  tailscale still names its home relay, so on a real tailnet every idle device read "via relay
  sao". That says nothing; a relay matters while you are using the connection.
- **Sign in only with an `AuthURL`.** The handoff draws a Sign in key for every signed-out
  machine. Tailscale gives a sign-in page only once a login has started; without one, a browser
  can't sign this machine in, so the popup shows `sudo tailscale up` to copy instead.
- **"back 1 min ago"** (the all-up board's row for a device that has just come back) is not shown:
  it needs a history of earlier answers, and the status has none.
- **"Last seen" order** sorts the online devices by their latest handshake (the one you talked to
  last first), then the offline ones by last seen. Online devices have no last-seen time of their
  own, so without the handshake "Last seen" would be the same as "Online first".
- **The widget shows at most 10 rows**, then "+N more in the bar's popup". The handoff's widget
  only drew six devices; a desktop card that grows with the tailnet would push the rest of the
  desktop away.
- **The widget off the tailnet** (not drawn in the handoff): the header with the state's chip, and
  one line of what the popup says, with Sign in when there is an `AuthURL`.
- **Font sizes are whole pixels.** The handoff's 13.5, 12.5 and 11.5 px became 14, 13 and 12:
  Qt's `font.pixelSize` takes an integer.
- **Icons are Material Symbols**, drawn with the theme's `iconFont`. The handoff's OS glyphs are
  its own SVGs; the plugin uses the nearest symbols (`computer`, `smartphone`, `laptop_mac`,
  `desktop_windows`, `phone_iphone`, `devices`). The shell can draw its own icons in another style
  (Solar); a plugin can't reach that, so these stay Material whatever that setting says.
- **Tabular figures** on the count (`tnum`), so `9/10` and `10/10` don't shift the pill's text.

## What it does not do yet

- Turn Tailscale on or off, or choose an exit node: both need root or `tailscale set --operator`
  (the handoff's note ts2, item 6). A later version could offer them when the operator is set.
- Show a device's own details beyond IP and DNS (its tags, its owner, its last handshake).
- Notice a change between two answers ("pad5 went offline"): there is no history kept.

## Checking it

- `scripts/test.sh`: the rules, with the coverage floor.
- `/usr/lib/qt6/bin/qmllint tailscale/*.qml tailscale/lib/*.qml`. Only `[syntax]`,
  `[read-only-property]` and `[incompatible-type]` matter; `host` is untyped, so "member not
  found" on it is expected. `/usr/bin/qmllint` is Qt 5's and reports nothing.
- **A live shell, without touching the installed one:** copy `~/.config/sekaipop`,
  `~/.local/state/sekaipop` and `~/.local/share/sekaipop` into a scratch folder, link this plugin
  into a scratch plugins folder, write `{"bar":true,"shown":true}` as its state, and run
  `XDG_CONFIG_HOME=… XDG_STATE_HOME=… XDG_DATA_HOME=… XDG_CACHE_HOME=… SEKAIPOP_PLUGINS_DIR=… qs -p <SekaiPop checkout>/sekaipop`.
  It draws a second bar under the first; `qs -p <checkout>/sekaipop ipc call plugins popup tailscale`
  opens the popup on the focused monitor. `grim` takes the pictures.
- **The other states:** put a fake `tailscale` first on that shell's `PATH`, printing a saved
  status with `BackendState` set to `Stopped`, `NeedsLogin` or `Starting`, or the "failed to
  connect to local tailscaled" line on stderr; a status with 25 peers for the big list.
