# Omado

A minimal todo list bar widget for [Omarchy](https://omarchyplugins.com/).

![preview](./preview.png) 


Add, complete, reorder, and clear tasks right from your bar. Tasks are stored in
`~/Dropbox/TODO.json` so the Dropbox desktop client can sync them between computers.

## Features

- Add tasks from the bar popup (Enter to confirm)
- Quick Add overlay from a global keyboard shortcut
- Drag any task to the top, middle, or bottom of the list
- Sync tasks through `~/Dropbox/TODO.json`
- Clear all completed tasks in one click
- Live "remaining" counter in the panel header
- Keyboard friendly: Esc closes, Tab switches panels

## Quick Add Shortcut

Omado exposes the global shortcut action `tamayotchi.omado:quick-add`. Bind it
to any key combination in your Hyprland bindings, for example:

```lua
o.bind("SUPER + SHIFT + T", nil, hl.dsp.global("tamayotchi.omado:quick-add"))
```

Reload Hyprland after adding the binding. Press the shortcut, enter a task, and
press Enter. Escape or clicking outside the dialog closes it without adding a
task. The plugin does not modify Hyprland configuration.

## Installation

Omado is a bar widget for the Omarchy shell (Quickshell). Install with the
Omarchy CLI:

```sh
omarchy plugin add https://github.com/tamayotchi/Omado --enable
```

Or clone it manually:

```sh
git clone https://github.com/tamayotchi/Omado ~/.config/omarchy/plugins/tamayotchi.omado
omarchy plugin enable tamayotchi.omado
```

## Removal

```sh
omarchy plugin remove tamayotchi.omado
```

This removes the plugin and its bar entry. Your saved tasks remain in
`~/Dropbox/TODO.json`; delete that file only if you also want to clear your data.

## Requirements

- Omarchy (Quickshell shell)
- A Dropbox folder at `~/Dropbox`

## License

[MIT](LICENSE)
