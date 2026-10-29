# Brief: Tailscale for SekaiPop (a bar entry, its popup, and a desktop widget)

Repository: https://github.com/masshirodev/sekaipop-tailscale (public). It's my repository and
my GitHub account is connected to claude.ai, so attach it to this session yourself with
read-only access (you never need to write to it), then make a shallow clone and read the code.
A plain `git clone` or `gh` has no credentials here, so don't start there. If attaching is
refused, ask me once to approve it rather than designing from this brief alone, and ask me for
the files only if that fails too.

It is new: this brief is its first file, and the plugin will be built here from your design.

**SekaiPop, the shell it lives in:** https://github.com/masshirodev/SekaiPop (my fork of
https://github.com/Blapples/SekaiPop, both public; attach the fork the same way). Read these:

- `docs/PLUGINS.md`: what a plugin is today, what the shell does for it (placing, dragging, the
  card frame, Edit Desktop, Focus Mode) and what the widget gets (`host`: theme, settings,
  `working`). **Read it whole.** Its theme names are the only colours and type a plugin can use.
- `sekaipop/modules/sekai/bar/`: the bar. The closest relatives of what is asked here are
  `DiscordPill.qml` + `DiscordPopup.qml` + `DiscordMemberRow.qml` (a pill with a count, a
  popup listing people with a status each), `WeatherIndicator.qml` + `WeatherPopup.qml`,
  `UpdatesBadge.qml`, and `SekaiPopup.qml` (the frame every bar popup shares: placement under
  its pill, the pop in and the shrink back into it).
- `sekaipop/services/BarLayoutService.qml` and `sekaipop/modules/sekai/settings/SettingsPageBar.qml`:
  the bar's modules and how the user arranges them in Settings > Bar.
- `sekaipop/modules/sekai/desktopWidgets/`: the built-in desktop cards, and
  `assets/shot-desktop-widgets.png` for how they look.
- `docs/briefs/PLUGIN-SETTINGS.md` and `docs/handoffs/plugin-settings/`: the last plugin brief
  and its handoff.
- https://github.com/masshirodev/sekaipop-kumiko (public): three plugin widgets already built
  from a design like this one. Their `doc/DESIGN.md` says how that design became widgets.

## What it is for

I run Tailscale on everything: this desktop, a server, a phone, two tablets, a Steam Deck. I want
to see at a glance that this machine is on the tailnet, and how many of my devices are up,
without opening a terminal. And when something does not answer, one click should show which
device is down and since when.

Three surfaces, one plugin:

| Surface            | Shows                                                         |
| ------------------ | ------------------------------------------------------------- |
| **Bar entry**      | this machine on the tailnet or not, and `online / total` devices |
| **Bar popup**      | every device in the tailnet with a status dot, opened by clicking the bar entry |
| **Desktop widget** | the same list as a desktop card, placed like any other plugin widget |

## There is no bar slot for plugins yet: it is part of this design

Today a plugin can only be a desktop widget. This work adds bar entries to SekaiPop's plugin
interface, so a plugin can put **its own item in the bar and its own popup under it**, without
breaking any plugin that exists. The plan, which the design may push back on:

- A plugin may ship `Bar.qml` (the item in the bar) and `Popup.qml` (the card under it) beside
  `Widget.qml`. Either is optional; a plugin with only `Bar.qml` has no popup.
- **The shell owns where and when**, as it does for desktop widgets: the entry is one more
  module in Settings > Bar (named and iconed from the manifest), arranged and switched off like
  Weather or Discord, on every bar edge (top, bottom, left, right: the bar can be vertical). The
  shell opens and closes the popup inside `SekaiPopup`'s frame, with the same pop in, the same
  click-away and Escape, and only one popup open at a time.
- **The plugin only draws**: the item's content and the popup card's face.

Design questions for that half:

1. Does the shell draw the pill's housing (outline, fill, shadow, like `StatusPill`), so every
   plugin entry matches the built-in ones, with the plugin drawing only inside? Or does the plugin
   draw the whole pill? (Desktop widgets have `frame: true / false` for the same choice.)
2. How a plugin entry looks in Settings > Bar's arranger, and whether it needs anything there
   the built-in ones don't (a mark that it is a plugin, a way to its plugin settings).
3. The vertical bar: what the entry becomes when the bar stands on the left or right edge.

## The data

From `tailscale status --json`, read every few seconds while something shows it. Field names
are Tailscale's. The sample is made up, but has the shape of mine.

- **This machine** (`Self` and `BackendState`): `Running` (on the tailnet), `Stopped` (Tailscale
  is off: `tailscale up` was not run, or was undone), `NeedsLogin` (signed out, with an `AuthURL`
  to sign in at), `Starting`, or **no daemon at all** (tailscaled is not running or not
  installed). Its `HostName` ("deskbox"), its Tailscale IPs (`100.71.8.4`, and an IPv6 one),
  its MagicDNS name (`deskbox.tail1234.ts.net`).
- **The tailnet**: its name (`CurrentTailnet.Name`, usually an email address) and the MagicDNS
  suffix.
- **Each other device** (`Peer`): `HostName`, `OS` (`linux`, `android`, `windows`, `macOS`,
  `iOS`), `Online` true or false, `LastSeen` (when an offline one was last there), its IPs and
  DNS name, `Active` (traffic is flowing with it right now), `Relay` / `CurAddr` (reached
  directly, or through a DERP relay like "fra": slower), `ExitNode` (this machine routes its
  traffic through it), `ExitNodeOption` (it offers to be one), and `KeyExpiry` (a key about to
  expire stops the device without warning).

Sample tailnet, 6 devices besides this one, 5 online:

| Device         | OS      | State                                         |
| -------------- | ------- | --------------------------------------------- |
| vps            | linux   | online, direct, offers exit node               |
| steamdeck      | linux   | online, active (a file copy running), relay "fra" |
| fold-phone     | android | online                                        |
| tab-s6         | android | online                                        |
| pad5           | android | online, key expires in 3 days                 |
| old-tablet     | android | offline, last seen 2 hours ago                 |

Actions worth having, small ones only (the design decides which earn a place):

- copy a device's IP or DNS name (the most common thing I'd do from the popup);
- open the Tailscale admin console (`https://login.tailscale.com/admin/machines`);
- when signed out: sign in (open the `AuthURL`).

Turning Tailscale on or off, or choosing an exit node, needs root (or the operator setting) and
is **not** asked for; say if you think it belongs.

## States to design

1. **Normal**: online, 5 of 6 up, with the sample above.
2. **Big tailnet**: 25 devices, long hostnames ("guilherme-work-laptop-2024"). Where does the
   popup stop growing and scroll; what is sorted first (online first? this machine on top? by
   name?).
3. **Everything up** and **only this machine** (a tailnet of one).
4. **This machine off the tailnet**: Tailscale stopped, signed out (with the sign-in action),
   or no daemon. The bar entry must be readable at a glance in each, and say which one in the
   popup. Should the entry hide itself when Tailscale is not installed?
5. **A device needs attention**: a key expiring soon, a device only reachable through a relay.
   Quiet, not alarming.
6. **The bar entry on a vertical bar**, and the entry next to its neighbours (Weather, Discord,
   the clock) so it is clearly one of them.
7. **The desktop widget**: a default size, and whether a compact look (the count and a row of
   dots) is worth a setting, as the Kumiko widgets have. And in Edit Desktop: the shelf tile.

## Settings the design may ask for

Plugin settings are strings, numbers and true / false, with labels, ranges and choices, edited
in Settings > Desktop > Plugins (already designed). Candidates: what the count counts (all
devices, or only mine when devices are shared into the tailnet), whether offline devices show in
the list, the sort order, how often to check, the bar entry's look (icon only, icon and count).
There is no secret: the `tailscale` command needs no token.

## Look

- **Only the theme's colours and type**, through the names `docs/PLUGINS.md` promises
  (`pSurface`, `pInk`, `pInkSub`, `pLine`, `chipFill`, `chipInk`, `accentCyan`, `accentMint`,
  `colBorder`, `dark`, `fontFamily`, `fontStyleBold`, `iconFont`, `borderWidth`, `radiusOuter`).
  If the status dots need colours the list does not have (an online green, an offline grey, a
  warning), say so: adding promised theme names is part of this work. It must work in Light,
  Dark and Darker, and with every theme, Matugen (colours from the wallpaper) included.
- The online / offline dot must not rely on colour alone (shape or fill too).
- Icons are Material Symbols names. Tailscale's logo is theirs, so no logo: a Material
  Symbols icon stands for it.
- Desktop widget clicks: anything clickable keeps its clicks, the rest of the card is the
  shell's drag handle, so leave plain card surface to grab.
- Motion small: a dot changing, a count ticking. The shell already pops the popup and the card
  in and out.

## When you are done

As the very last step, append ` [finished]` to this artifact's title and add a closing line
`Status: finished` to the page itself. That is how the implementing agent knows the design is
complete. The agent polls from the kizuna profile `max`, so the design should live on the account
that profile is signed in to; otherwise the handoff is downloaded into this repo's
`doc/briefs/` by hand.
