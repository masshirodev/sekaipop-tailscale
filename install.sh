#!/bin/sh
# Links the plugin into SekaiPop's plugins folder and reloads the shell's plugins. Run it from
# the clone; `git pull` there later updates it (then reload again).
#
#   ./install.sh            link tailscale, and put its entry on the bar
#   ./install.sh --remove   take the link away (its saved settings stay)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
plugins="${SEKAIPOP_PLUGINS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/sekaipop/plugins}"
dest="$plugins/tailscale"
mkdir -p "$plugins"
if [ "${1:-}" = "--remove" ]; then
    [ -L "$dest" ] && rm "$dest" && echo "removed tailscale"
    command -v qs >/dev/null 2>&1 && qs -c sekaipop ipc call plugins reload >/dev/null 2>&1 || true
    exit 0
fi
if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "$dest exists and is not a link: left alone" >&2
    exit 1
fi
ln -sfn "$here/tailscale" "$dest"
echo "linked tailscale"
if command -v qs >/dev/null 2>&1; then
    qs -c sekaipop ipc call plugins reload >/dev/null 2>&1 || true
    # The scan takes a moment; then the entry goes on the bar (it starts off).
    sleep 1
    qs -c sekaipop ipc call plugins bar tailscale on 2>/dev/null \
        || echo "Turn the entry on in Settings > Bar > Modules (needs a SekaiPop with plugin bar entries)."
fi
echo "The widget: add Tailscale from Edit Desktop (right-click the desktop)."
