# sekaipop-tailscale

A [SekaiPop](https://github.com/Blapples/SekaiPop) plugin that shows your Tailscale status: an
entry in the bar (this machine on the tailnet or not, and how many devices are up), a popup
under it listing every device in the tailnet with a status dot, and the same list as a desktop
widget.

**Not built yet.** It waits on two things:

- the design: `doc/briefs/TAILSCALE.md` is the brief for it;
- bar entries for plugins in SekaiPop's plugin interface (today a plugin can only be a desktop
  widget). That part goes to SekaiPop as its own PR.

Needs `tailscale` on the `PATH`; no token.
