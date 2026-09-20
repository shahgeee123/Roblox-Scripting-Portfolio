# UI System

A small panel controller with cancellable transitions and explicit cleanup. It illustrates interface lifecycle management independently of a game's inventory implementation.

## Install

Place the `PanelController` ModuleScript and the `PanelDemo` LocalScript together in StarterPlayer → StarterPlayerScripts. Start Play, then use the button or press B. The demo builds its UI from code and requires no image assets. `Activated` supports the button's mouse/touch interaction; B is an additional keyboard shortcut.

## API

```lua
local controller = PanelController.new(panelFrame, toggleButton)
controller.SetOpen(true) -- dot call, not colon
controller.SetOpen(false)
controller.Destroy() -- call before discarding the UI
```

An incoming transition disconnects the old completion callback before cancelling the old tween. A stale callback therefore cannot hide a newly reopened panel. The focused-textbox check avoids toggling while typing. Destroy is idempotent and releases the input/button connections and active transition. The demo connects cleanup to the ScreenGui's destruction; it persists across character respawns.

The controller owns the panel's Position and Visible properties while active; avoid another script animating those properties simultaneously. It does not destroy the caller-owned instances. The demo is a panel shell, not a populated inventory UI, modal input blocker, or complete controller-navigation system.
