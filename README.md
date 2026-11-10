# Global Menu

A macOS-style menu bar for Noctalia Shell. The focused application's menus
move into the top bar: the app name plus one label per top-level menu, with a
popup that renders the full menu tree — checkmarks, accelerators, submenus and
keyboard navigation — and activates items in the real application. Clicking
the app name opens a macOS-style application menu (About, Minimize, Maximize,
Fullscreen, Resize and Quit), and menu labels that do not fit the bar move
under a » button instead of being cut off.

## Plugin

| Field | Value |
| --- | --- |
| ID | `amancode22/noctalia-gmenu` |
| Entries | Bar widget: `menubar`; panel: `menu`; service: `service` |

## Requirements

- `python3` with `python3-dbus` and `python3-gi` on `PATH` (the manifest
  declares exactly these). The plugin spawns its Python companion daemon
  automatically; you never run it by hand.
- Window tracking uses the standard `wlr_foreign_toplevel_management_unstable_v1`
  Wayland protocol. This is **not** a compositor-specific binding: under
  Wayland's security model no client can see other windows or read input
  focus directly, so a global menu must ask the compositor, and this one
  protocol is the only compositor-agnostic way to do that. Any compositor
  that speaks it works identically — Hyprland, niri, sway, river, Wayfire,
  labwc, KWin, MangoWC and others. No compositor-specific IPC (`hyprctl`,
  `niri msg`, `swaymsg`, ...) is used anywhere.
- `wtype` on `PATH` if you want **shortcut menus**: item clicks either
  activate a GTK action on the application's own action bus (GIMP-style
  mappings) or synthesize real keystrokes into the focused window.
- For native menus, the application must either register with the AppMenu
  registrar (most Qt, Electron, Chromium and Firefox apps) or export a
  GTK menubar (GTK 3/4 apps). Applications that do neither fall back to
  curated shortcut menus or window/session actions.

## How it works

A service entry spawns the Python daemon and streams its JSON output. The
daemon owns all D-Bus and Wayland work and publishes menu snapshots to the
plugin state channel; commands flow back over a loopback-only HTTP endpoint
whose port is negotiated in the daemon's hello line. Menu sources, in order
of preference per focused application:

1. `com.canonical.dbusmenu` via the AppMenu registrar
2. `org.gtk.Menus`
3. Curated shortcut mappings (bundled in `daemon/shortcuts/apps.zip`)
4. Fallback window and session actions

The bar widget renders the focused app's name and its top-level menu labels
and hides itself entirely when there is nothing to show. Because the shell
gives a bar widget no width to read, the strip is budgeted from the bar's
output width (or the *Menu bar width budget* setting) using conservative text
estimates; every label pushed out of the budget stays reachable under the »
button, which opens the same popup with the overflowed menus listed.

## Install

### From the plugin store

The plugin lives in the Noctalia community store. Enable it directly:

```sh
noctalia msg plugins enable amancode22/noctalia-gmenu
```

or open **Settings → Plugins**, find **Global Menu** under the community
source and toggle it on. Store installs update automatically with the
*Auto-update plugins* setting.

### From a git clone

```sh
mkdir -p ~/noctalia-plugins
git clone https://github.com/AmanCode22/noctalia-gmenu \
    ~/noctalia-plugins/noctalia-gmenu
noctalia msg plugins source add my-plugins path ~/noctalia-plugins
noctalia msg plugins enable amancode22/noctalia-gmenu
```

Pulling with `git pull` inside the clone and running
`noctalia msg plugins update my-plugins` picks up new versions.

Once enabled — from either method — open Noctalia's settings, add the
**Global Menu** widget to your bar and make sure the Python dependencies
above are installed. The daemon starts with the plugin and is restarted
automatically if its heartbeat is lost; it is stopped cleanly when the
plugin is disabled, reloaded or uninstalled.

## Usage

- Click a menu label in the bar to open the popup on that menu; click the
  same label again (or re-click the app name) to close it. Switching labels
  while the popup is open closes and reopens it, so it re-anchors under the
  freshly clicked label like on macOS.
- Click the **application name** to open the app menu: *About <app>* (opens
  an info view with the app id, menu source and window state), *Minimize*,
  *Maximize*, *Fullscreen* (with live checkmarks), a *Resize* group
  (*Restore Size*, *Maximize*, *Fullscreen*) and *Quit <app>* — which
  activates the application's own Quit item when it exports one, and
  otherwise closes every window of the app.
- Inside the popup: `Up`/`Down` move the selection, `Right` enters a submenu,
  `Left` goes back, `Return` activates. Clicks work too, and a back row with
  breadcrumbs appears inside submenus.
- Window actions use the foreign-toplevel protocol only; exact pixel resize
  is not part of that protocol, so the Resize group offers the maximize /
  fullscreen / restore geometry options instead.
- Open or close the popup from a terminal:

```sh
noctalia msg panel-toggle amancode22/noctalia-gmenu:menu
```

### Custom shortcut menus

Your own per-app mappings override the shipped ones. Drop JSON files with
the same format as the bundled mappings in `daemon/shortcuts/apps.zip` into:

```
~/.config/noctalia/global-menu/shortcuts/apps
```

To have them picked up, toggle any plugin setting (which triggers a config
push) or reload the plugin. Changing the *Shortcut menus* setting instantly
enables or disables this whole source in the daemon.

## Settings

| Setting | Default | Description |
| --- | --- | --- |
| Show application name | on | Show the focused app's name in front of its menus. |
| Shortcut menus | on | Curated menus for apps that export none; clicks activate GTK actions or send keystrokes (`wtype`). |
| Fallback menus | on | Window and session actions for apps with no menu at all. |
| Menu labels in the bar (widget) | 0 | Hard cap on top-level labels; 0 shows every menu. |
| Menu bar width budget (widget) | 0 | Max width in px before labels move under »; 0 fits to half of the screen width. |

## Troubleshooting

- **Widget never appears.** Check that `python3-dbus` and `python3-gi` are
  installed; on failure the plugin raises a notification saying exactly that.
  Plugin log lines carry the `[global-menu]` prefix.
- **"No menu for this window" in the popup.** The focused app exposes neither
  a D-Bus menu nor a GTK menubar and shortcut/fallback menus are disabled (or
  the app has no curated mapping). Try enabling *Shortcut menus* and
  *Fallback menus*.
- **Shortcut menu clicks do nothing.** Install `wtype`; it is the only way to
  synthesize keystrokes into a Wayland window without compositor-specific
  calls.
- **Menus are stale after changing an app's own settings.** Toggle the popup
  closed and open, or reload the plugin, to force a fresh tree.

## Credits

This plugin is a port of [orbit-global-menu](https://github.com/Unmade760/orbit-global-menu/)
by [Unmade760](https://github.com/Unmade760), adapted to run as a Noctalia
Shell plugin. Special thanks to Unmade760 for making the original extension —
this project would not exist without it.

## License

GPL-3.0-or-later; see `LICENSE`.
