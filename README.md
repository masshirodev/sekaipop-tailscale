# sekaipop-tailscale

A [SekaiPop](https://github.com/Blapples/SekaiPop) plugin that shows your Tailscale status:

| Surface            | Shows                                                                                         |
| ------------------ | --------------------------------------------------------------------------------------------- |
| **Bar entry**      | whether this machine is on the tailnet (the icon), and how many devices are up (`5/6`)        |
| **Popup**          | a click on the entry: this machine with its IP and MagicDNS name, then every device with a status dot |
| **Desktop widget** | the same list as a card (or, compact, the count and a dot per device)                         |

Clicking a device copies its IP; in the popup, hovering it shows IP and DNS keys. A device whose
key ends within a week gets a small amber diamond, and the bar's icon gets one too. When this
machine is off the tailnet (Tailscale off, signed out, tailscaled not running), the popup says what
to do, with the command to copy.

## Install

```sh
git clone https://github.com/masshirodev/sekaipop-tailscale.git ~/projects/sekaipop-tailscale
cd ~/projects/sekaipop-tailscale && ./install.sh
```

`install.sh` links the `tailscale` folder into `~/.config/sekaipop/plugins/`, reloads the shell's
plugins and puts the entry on the bar. Move it in Edit Desktop's BAR tab; add the widget from
Edit Desktop's shelf. `git pull` updates it; `./install.sh --remove` takes it away.

Needs a SekaiPop with plugin bar entries (plugin api 1, Blapples/SekaiPop#103), `tailscale` on
the shell's `PATH`, and `wl-copy` for the copy keys. No token: `tailscale status` needs none.

A keybind for the popup: `qs -c sekaipop ipc call plugins popup tailscale`.

## Settings

Settings > Desktop > Plugins > Tailscale:

| Group    | Setting                | Default         |                                                      |
| -------- | ---------------------- | --------------- | ---------------------------------------------------- |
| Bar      | Bar entry              | Icon and count  | or Icon only (a status dot on the icon)              |
| Bar      | Hide without Tailscale | on              | off the bar when the `tailscale` command isn't there |
| Devices  | Count                  | All devices     | or Only mine (devices shared in by others left out)  |
| Devices  | Offline devices        | Fold            | Show, Fold (more than 3 under one line), Hide        |
| Devices  | Order                  | Online first    | By name, Last seen                                   |
| Widget   | Look                   | Full            | or Compact                                           |
| Checking | Check every            | 5 seconds       | while the popup or the widget shows; the bar alone checks every 30 s |

## Working on it

- `tailscale/lib/Tailscale.js` is every rule (states, the count, order, attention, folding, the
  entry's words), as pure functions; the QML only draws what it returns.
- `scripts/test.sh` runs its tests with the 95 % coverage floor.
- `doc/DESIGN.md` is how the design became the plugin, where it departs from it, and how to check
  the QML; `doc/briefs/` holds the brief and the handoff.
