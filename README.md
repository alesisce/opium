# OpiumUI

A compact, flat UI library for Roblox. 4px component corners, an 8px window shell, tab groups, live theming, native notifications, handles and JSON-backed configuration — all in a single Luau module with no dependencies.

OpiumUI is designed for script UIs: small, predictable, and easy to wire to real functionality.

- **Single file.** Drop `OpiumUI.luau` into your project and require it.
- **Compact.** 28px header, 125px sidebar, 30px tabs, 11–12px text.
- **Flat.** Solid surfaces, 1px strokes, no gradients or drop shadows.
- **Complete.** Tabs, groups, sections, seven controls, notifications, config.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
  - [Window](#window)
  - [Tabs and Tab Groups](#tabs-and-tab-groups)
  - [Sections](#sections)
  - [Components and Handles](#components-and-handles)
- [API Reference](#api-reference)
  - [UI](#ui)
  - [UI.Window(options)](#uiwindowoptions)
  - [Window Options](#window-options)
  - [Window Methods](#window-methods)
  - [TabGroup](#tabgroup)
  - [Tab](#tab)
  - [Section](#section)
  - [Component Handles](#component-handles)
- [Notifications](#notifications)
- [Configuration](#configuration)
- [Theming](#theming)
- [Visual Specifications](#visual-specifications)
- [Full Example](#full-example)
- [Notes and Limitations](#notes-and-limitations)
- [Roadmap](#roadmap)

---

## Features

| Feature | Description |
| --- | --- |
| Window shell | Draggable, resizable, optional toggle key, custom size and position. |
| Tab groups | Group tabs under small uppercase headers in the sidebar. |
| Tab animations | Slide-in page transition and color fades, globally or per tab. |
| Controls | Button, Toggle, Slider, Input, Dropdown, Stat, Label, Divider. |
| Handles | Every control returns an object with `Set`, `Get`, `SetVisible` and `Destroy`. |
| Live theming | Recolor an open window instantly; copy a theme to another window. |
| Notifications | Stacked toasts with `info`, `success`, `error` and `warning` types. |
| Config | Automatic keys, `GetValues` / `SetValues`, JSON `SaveConfig` / `LoadConfig`. |
| Tooling | Section visibility, per-tab animations, resize grip, keybind toggle. |

---

## Installation

OpiumUI is a single module that returns a table. Choose the loading method that matches your environment.

### Roblox project (ModuleScript)

Place `OpiumUI.luau` as a ModuleScript and require it:

```lua
local UI = require(script.Parent.OpiumUI)
```

### Executor / script workspace

If `OpiumUI.luau` lives in the executor workspace:

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/alesisce/opium/refs/heads/main/OpiumUI.luau"))()
```

The demo (`OpiumUI_Demo.luau`) uses this pattern.

> **Requirements:** the library is client-side. It uses `Players.LocalPlayer`, `UserInputService`, `TweenService` and `HttpService`. Config save/load additionally requires `writefile` / `readfile` (executor or Studio with file access).

---

## Quick Start

```lua
local UI = loadstring(readfile("OpiumUI.luau"))()

local Win = UI.Window{
    Title = "My Script",
    Subtitle = "v1.0",
    Width = 470,
    Height = 580,
    Position = UDim2.fromOffset(40, 40),
    ToggleKey = Enum.KeyCode.RightShift,
}

local mainGroup = Win:TabGroup("Main")
local tab = mainGroup:Tab("Movement")
local section = tab:Section("Player")

local speed = section:Slider("Walk speed", 0, 100, 16, function(value)
    print("speed:", value)
end)

local enabled = section:Toggle("Enabled", true, function(state)
    print("enabled:", state)
end)

section:Button("Reset", function()
    enabled:Set(true)
    speed:Set(16)
    Win:Notify("Defaults restored", { Type = "success" })
end)

Win:Notify("Loaded")
```

---

## Core Concepts

### Window

`UI.Window(options)` creates a `ScreenGui` containing one draggable, resizable window and returns a **Window** object.

- The window is parented to `gethui()` when available (executors), otherwise to `PlayerGui`.
- `ToggleKey` shows/hides the window from anywhere.
- The header can be dragged; the bottom-right grip resizes it.
- `Win:Destroy()` disconnects all internal connections and destroys the `ScreenGui`.

### Tabs and Tab Groups

Sidebar entries are created with either:

```lua
local tab = Win:Tab("Dashboard")       -- standalone tab
```

or grouped:

```lua
local settings = Win:TabGroup("Settings")
local audio = settings:Tab("Audio")
local video = settings:Tab("Video")
```

Group headers are rendered as small uppercase labels. Tabs created through the same `TabGroup` object share one header. The first tab is selected automatically.

Each tab has its own scrolling page; page content never overflows visually.

### Sections

A section is a vertical block inside a tab, with an optional uppercase title and a hairline rule:

```lua
local section = tab:Section("Movement")
```

Sections stack with consistent spacing and can be hidden as a whole:

```lua
section:SetVisible(false)
```

### Components and Handles

Every control is created from a section and returns a **handle**:

```lua
local toggle = section:Toggle("Enabled", true, callback)
local slider = section:Slider("Speed", 0, 200, 16, callback)
local input  = section:Input("Name", "type here", callback)
local select = section:Dropdown("Mode", {"A", "B"}, "A", callback)
local stat   = section:Stat("FPS", "—")
```

Handles expose:

```lua
toggle:Get()             -- current value
toggle:Set(false)        -- set + fire callback
toggle:Set(false, true)  -- set without firing
toggle:SetVisible(false) -- hide just this control
toggle:Destroy()

stat("60")               -- handles are callable (same as :Set)
```

Controls are registered with the window automatically, so their values can be read and persisted ([Configuration](#configuration)).

---

## API Reference

### UI

The module returns a table with two members:

| Member | Type | Description |
| --- | --- | --- |
| `UI.Window(options)` | function | Creates a window. Returns a [Window](#window-methods). |
| `UI.Theme` | table | Default theme. Change it **before** creating windows to set global defaults. |

---

### UI.Window(options)

Creates a window and its `ScreenGui`.

**Returns:** `Window`

```lua
local Win = UI.Window{
    Title = "Opium",
    Width = 470,
    Height = 580,
    PrimaryColor = Color3.fromHex("#6C8EBF"),
}
```

---

### Window Options

All fields are optional.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Title` | `string` | `"Opium"` | Header title. |
| `Subtitle` | `string?` | `nil` | Small right-aligned text in the header. |
| `Width` | `number` | `400` | Window width in pixels. |
| `Height` | `number` | `440` | Window height in pixels. |
| `Size` | `UDim2?` | `nil` | Overrides `Width` / `Height` when provided. |
| `MinWidth` | `number` | `340` | Minimum width used by resizing and `SetSize`. |
| `MinHeight` | `number` | `220` | Minimum height used by resizing and `SetSize`. |
| `Resizable` | `boolean` | `true` | Enables the bottom-right resize grip. |
| `Position` | `UDim2` | `UDim2.fromOffset(60, 60)` | Initial position. |
| `ToggleKey` | `Enum.KeyCode?` | `nil` | Key that shows/hides the window. |
| `AnimateTabs` | `boolean` | `true` | Slide/fade animation when switching tabs. |
| `PrimaryColor` | `Color3` | `#C25A52` | Accent: toggles, slider fill, focus, selection. |
| `BgColor` | `Color3` | `#141519` | Window background. |
| `HeaderColor` | `Color3` | `#17181D` | Header background. |
| `SidebarColor` | `Color3` | `#101114` | Sidebar background. |
| `InputColor` | `Color3` | `#101114` | Text box background. |
| `RaisedColor` | `Color3` | `#1B1D22` | Buttons, dropdown header, options. |
| `HoverColor` | `Color3` | `#23262C` | Hover background. |
| `PressedColor` | `Color3` | `#2A2D34` | Pressed background. |
| `BorderColor` | `Color3` | `#262930` | Strokes, separators, scrollbar. |
| `TrackColor` | `Color3` | `#2E3138` | Toggle and slider tracks. |
| `TextColor` | `Color3` | `#E7E8EA` | Primary text. |
| `MutedColor` | `Color3` | `#8B8F98` | Secondary text and section headers. |
| `DimColor` | `Color3` | `#5B5F68` | Placeholders, chevrons, hints. |

Default palette (also available in `UI.Theme`):

```
#C25A52  accent
#141519  background
#17181D  header
#101114  sidebar / input
#1B1D22  raised
#23262C  hover
#2A2D34  pressed
#262930  border
#2E3138  track
#E7E8EA  text
#8B8F98  muted
#5B5F68  dim
```

---

### Window Methods

#### `Win:Tab(name)`

Creates a standalone tab at the end of the sidebar.

- **Parameters:** `name: string`
- **Returns:** `Tab`

```lua
local tab = Win:Tab("Dashboard")
```

#### `Win:TabGroup(label)`

Creates a group header in the sidebar. Tabs added through the returned object appear under it.

- **Parameters:** `label: string`
- **Returns:** `TabGroup`

```lua
local group = Win:TabGroup("Settings")
local tab = group:Tab("Audio")
```

#### `Win:Toggle()`

Shows the window if hidden, hides it if visible.

- **Returns:** `nil`

#### `Win:SetVisible(visible)`

Sets window visibility explicitly.

- **Parameters:** `visible: boolean`
- **Returns:** `nil`

#### `Win:SetSize(width, height)`

Resizes the window. Values are clamped to `MinWidth` / `MinHeight` and to the viewport minus 40px.

- **Parameters:** `width: number`, `height: number`
- **Returns:** `nil`

```lua
Win:SetSize(520, 640)
```

#### `Win:SetTabAnimation(enabled)`

Enables or disables the tab transition globally.

- **Parameters:** `enabled: boolean`
- **Returns:** `Window` (self)

#### `Win:GetTheme()`

Returns the live theme table of this window.

- **Returns:** `table`

The returned table is the same object the window uses internally. Read it to copy a theme:

```lua
local theme = Win:GetTheme()
```

#### `Win:SetTheme(input)`

Recolors the window and all of its components **in place**. Position, size, active tab, control values and state are preserved.

- **Parameters:** `table` — color props (`PrimaryColor`, `BgColor`, …), a theme table (`accent`, `ui`, …), or another `Window`
- **Returns:** `nil`

```lua
Win:SetTheme{
    PrimaryColor = Color3.fromHex("#6C8EBF"),
    BgColor = Color3.fromHex("#12161C"),
}

Win:SetTheme(otherWindow)        -- copy another window's theme
Win:SetTheme(UI.Theme)           -- restore global defaults
```

#### `Win:GetValues()`

Returns the current value of every value-bearing control, keyed by its configuration key.

- **Returns:** `table<string, any>`

```lua
local values = Win:GetValues()
-- {
--   ["Controls/Behavior/Live stats"] = true,
--   ["Controls/Sampling/Sample rate (ms)"] = 500,
--   ["Config/Profile/Name"] = "default",
-- }
```

`Stat` controls are excluded because they are read-only. Buttons, labels and dividers have no value.

#### `Win:SetValues(values, fireCallbacks?)`

Applies a table of values produced by `GetValues`. Unknown keys are ignored.

- **Parameters:** `values: table`, `fireCallbacks: boolean?` (default `false`)
- **Returns:** `boolean` — `false` if `values` is not a table

```lua
Win:SetValues(values)        -- silent: callbacks do NOT run
Win:SetValues(values, true)  -- callbacks run for every applied value
```

#### `Win:SaveConfig(path?)`

Serializes `GetValues()` to JSON and writes it to the executor workspace.

- **Parameters:** `path: string?` (default `"opium_config.json"`)
- **Returns:** `boolean, string?` — success and an error message on failure

```lua
local ok, err = Win:SaveConfig("my_config.json")
if not ok then
    warn("Save failed:", err)
end
```

#### `Win:LoadConfig(path?, fireCallbacks?)`

Reads a JSON config and applies it with `SetValues`.

- **Parameters:** `path: string?`, `fireCallbacks: boolean?` (default `false`)
- **Returns:** `boolean, string?` — success and an error message on failure

```lua
local ok, err = Win:LoadConfig("my_config.json")
if not ok then
    Win:Notify("Could not load config", { Type = "error" })
end
```

#### `Win:Notify(message, options?)`

Shows a stacked notification at the bottom-right of the screen.

- **Parameters:**
  - `message: string`
  - `options: table? | number?` — a number is treated as `Duration`
    - `Type`: `"info" | "success" | "error" | "warning"` (default `"info"`)
    - `Duration`: number in seconds (default `2.6`)
- **Returns:** `Notification` — `{ frame: Frame, dismiss: function }`

```lua
Win:Notify("Saved")
Win:Notify("Save failed", { Type = "error", Duration = 4 })
Win:Notify("Loaded", 3)
```

See [Notifications](#notifications) for behavior and colors.

#### `Win:Destroy()`

Disconnects internal connections, stops notifications and destroys the `ScreenGui`.

- **Returns:** `nil`

---

### TabGroup

Returned by `Win:TabGroup(label)`.

#### `Group:Tab(name)`

Creates a tab inside the group.

- **Parameters:** `name: string`
- **Returns:** `Tab`

```lua
local group = Win:TabGroup("Settings")
local audio = group:Tab("Audio")
local video = group:Tab("Video")
```

---

### Tab

Returned by `Win:Tab(name)` and `Group:Tab(name)`.

#### `Tab:Section(title?)`

Creates a section inside the tab.

- **Parameters:** `title: string?` — rendered uppercase with a hairline rule
- **Returns:** `Section`

```lua
local section = tab:Section("Movement")
local freeform = tab:Section()  -- no header
```

#### `Tab:SetAnimation(enabled)`

Overrides the global tab animation for this tab.

- **Parameters:** `enabled: boolean`
- **Returns:** `Tab` (self)

```lua
local tab = group:Tab("Audio")
tab:SetAnimation(false)
```

---

### Section

Returned by `Tab:Section(title?)`.

#### `Section:SetVisible(visible)`

Shows or hides the entire section. Hidden sections are removed from layout flow.

- **Parameters:** `visible: boolean`
- **Returns:** `Section` (self)

#### `Section:Button(label, onClick?)`

Creates a full-width button.

- **Parameters:** `label: string`, `onClick: function?`
- **Returns:** `Component` (no value)
- **Callback:** `onClick()`

```lua
section:Button("Copy position", function()
    setclipboard("0, 0, 0")
end)
```

#### `Section:Toggle(label, default?, onChange?)`

Creates a labeled switch with an animated knob.

- **Parameters:** `label: string`, `default: boolean?`, `onChange: function?`
- **Returns:** `Component` — value is `boolean`
- **Callback:** `onChange(state: boolean)`

```lua
local enabled = section:Toggle("Enabled", true, function(state)
    print(state)
end)
```

#### `Section:Slider(label, min, max, default?, onChange?)`

Creates a labeled slider with a value readout in monospace.

- **Parameters:** `label: string`, `min: number`, `max: number`, `default: number?`, `onChange: function?`
- **Returns:** `Component` — value is `number`
- **Callback:** `onChange(value: number)` (fires continuously while dragging)

```lua
local speed = section:Slider("Speed", 0, 200, 16, function(value)
    print(value)
end)
```

> The slider has no step/quantization. Values are floats; the readout hides decimals for integers.

#### `Section:Input(label, placeholder?, onCommit?)`

Creates a labeled text field.

- **Parameters:** `label: string`, `placeholder: string?`, `onCommit: function?`
- **Returns:** `Component` — value is `string`
- **Callback:** `onCommit(text: string)` — fires on focus lost

```lua
local name = section:Input("Name", "type here", function(text)
    print(text)
end)

name:Set("default", true)  -- set without firing
```

#### `Section:Dropdown(label, options, default?, onChange?)`

Creates a select-style dropdown that expands inline.

- **Parameters:** `label: string`, `options: table`, `default: any?`, `onChange: function?`
- **Returns:** `Component` — value is the selected option
- **Callback:** `onChange(value: any)`
- **Behavior:** clicks outside the dropdown close it (mouse); selecting an option closes it.

```lua
local mode = section:Dropdown("Mode", {"Legit", "Rage", "Custom"}, "Legit", function(value)
    print(value)
end)
```

#### `Section:Stat(label, value?)`

Creates a read-only label/value row. Values are rendered in a monospace font.

- **Parameters:** `label: string`, `value: string?` (default `"—"`)
- **Returns:** `Component` — read-only; excluded from `GetValues`
- **Callable:** `stat("60")` is equivalent to `stat:Set("60")`

```lua
local setFps = section:Stat("FPS", "—")
setFps("60")
setFps:Set("61")
```

#### `Section:Label(text)`

Creates wrapped muted text.

- **Parameters:** `text: string`
- **Returns:** `Component` (no value)

#### `Section:Divider()`

Creates a 1px horizontal separator.

- **Returns:** `Component` (no value)

---

### Component Handles

Every section control returns the same handle shape.

| Member | Type | Description |
| --- | --- | --- |
| `handle:Get()` | function | Returns the current value. `nil` for buttons, labels and dividers. |
| `handle:Set(value, silent?)` | function | Sets the value. Fires the callback unless `silent` is `true`. Returns the handle. |
| `handle:SetVisible(visible)` | function | Shows/hides the control. Hidden controls are removed from layout. |
| `handle:Destroy()` | function | Destroys the underlying instance. |
| `handle(value)` | metamethod | Same as `handle:Set(value)`. Useful for `Stat` setters. |
| `handle.instance` | `Instance` | The underlying GuiObject (TextBox, TextButton, Frame, …). |
| `handle.kind` | `string` | `"button"`, `"toggle"`, `"slider"`, `"input"`, `"dropdown"`, `"stat"`, `"label"`, `"divider"`. |
| `handle.key` | `string?` | Auto-generated key. Present on registered controls (including `Stat`). |
| `handle.window` | `Window?` | The owning window. |

---

## Notifications

`Win:Notify` creates a toast inside the window's `ScreenGui`.

**Behavior**

- Anchored bottom-right, 260px wide.
- Slides in from the right and fades in (0.16s); fades out on dismissal.
- Auto-dismisses after `Duration` seconds (default `2.6`).
- Stacked upward with 36px spacing, maximum **4** visible; the oldest is dismissed first.
- Destroyed with the window.

**Types**

| Type | Bar color | Use |
| --- | --- | --- |
| `info` | muted gray | Neutral messages |
| `success` | `#7CB08A` | Saved, loaded, applied |
| `error` | `#C96B63` | Failures |
| `warning` | `#C3A05C` | Missing config, caution |

**Record**

```lua
local toast = Win:Notify("Working…", { Type = "info", Duration = 10 })
toast.dismiss()   -- dismiss early
toast.frame       -- the underlying Frame
```

**Examples**

```lua
Win:Notify("Ready")
Win:Notify("Config saved", { Type = "success" })
Win:Notify("File not found", { Type = "warning", Duration = 4 })
Win:Notify("Could not write file", { Type = "error" })
```

---

## Configuration

Value controls are registered with the window and receive an automatic key:

```
<Tab name>/<Section title>/<Control label>
```

Examples:

```
Controls/Behavior/Live stats
Controls/Sampling/Sample rate (ms)
Config/Profile/Name
```

Rules:

- Sections without a title use `General` in the key.
- If two controls share the same key, `#2`, `#3`, … is appended.
- `Stat` is read-only and excluded from `GetValues`.
- `Button`, `Label` and `Divider` have no value.
- Read `handle.key` to inspect the generated key.

**Manual snapshot**

```lua
local values = Win:GetValues()
-- inspect, store, or send over HTTP
```

**Round trip**

```lua
local ok = Win:SaveConfig("opium_config.json")
Win:SetValues{ ["Controls/Behavior/Live stats"] = false }
Win:LoadConfig("opium_config.json")          -- silent reload
Win:LoadConfig("opium_config.json", true)    -- reload and fire callbacks
```

**Silent vs. callback**

| Method | Default | Fire callbacks |
| --- | --- | --- |
| `handle:Set(value)` | fires | yes |
| `handle:Set(value, true)` | silent | no |
| `Win:SetValues(values)` | silent | no |
| `Win:SetValues(values, true)` | fires | yes |
| `Win:LoadConfig(path)` | silent | no |
| `Win:LoadConfig(path, true)` | fires | yes |

Use silent loading when callbacks have side effects you do not want to repeat (teleports, network calls). Use firing loading when the callback applies the value to the game state.

**Example JSON**

```json
{
  "Controls/Behavior/Live stats": true,
  "Controls/Behavior/Show graph": true,
  "Controls/Appearance/Theme": "Charcoal",
  "Controls/Appearance/UI scale (%)": 100,
  "Controls/Sampling/Sample rate (ms)": 500,
  "Config/Profile/Name": "default"
}
```

**Caveats**

- Values must be JSON-serializable: strings, numbers, booleans, arrays and plain objects. `Color3`, `Instance` and functions are not.
- `SaveConfig` / `LoadConfig` require `writefile` / `readfile`. In environments without them the methods return `false` and an error.
- Loading ignores keys that do not exist in the current UI.
- Labels are part of the key: renaming a control invalidates its saved value.

---

## Theming

### Per-window colors

Pass any color prop to `UI.Window` (see [Window Options](#window-options)). Each window resolves its own theme, so different windows can look different at the same time.

### Live re-theming

`SetTheme` repaints the existing window without rebuilding it:

```lua
Win:SetTheme{
    PrimaryColor = Color3.fromHex("#C96B63"),
    BgColor = Color3.fromHex("#0F1113"),
    BorderColor = Color3.fromHex("#252B2F"),
}
```

- Preserves size, position, active tab and control values.
- Updates backgrounds, text, strokes, placeholders and scrollbars.
- Hover/pressed states read from the live theme, so they stay correct.

### Copying themes

```lua
local settingsWindow = UI.Window{ Title = "Settings" }
settingsWindow:SetTheme(mainWindow)
```

### Reading the current theme

```lua
local theme = Win:GetTheme()
print(theme.accent, theme.ui, theme.text)
```

### Global defaults

```lua
UI.Theme.accent = Color3.fromHex("#6C8EBF")
UI.Theme.text = Color3.fromHex("#EAECEF")
```

Set global defaults **before** creating windows. `SetTheme` never modifies `UI.Theme`.

### Limitations

- `SetTheme` changes colors only. Fonts and radius are fixed at window creation.
- Repainting works by remapping old theme colors to new ones. If two theme roles share the same color, they remap together.
- Notifications follow live theme colors through the same repaint pass.

---

## Visual Specifications

| Element | Value |
| --- | --- |
| Window corner radius | 8px (UIStroke 1px border) |
| Component corner radius | 4px |
| Header height | 28px |
| Sidebar width | 125px |
| Tab height | 30px |
| Tab text | 12px `GothamMedium` |
| Section header | 10px uppercase + 1px rule |
| Body text | 11px |
| Stat values | 11px `Code` |
| Control heights | 20–36px |
| Window default size | 400 × 440 |
| Resize grip | 3 lines, inset 11px from the corner |
| Hover transition | 80ms |
| Tab transition | 120–180ms slide + color fade |
| Notification transition | 160ms |

The window shell uses independent corner radii on the header and sidebar so the outer 8px corner is never covered. Roblox `UICorner` does not clip descendants; this is handled internally.

---

## Full Example

```lua
local UI = loadstring(readfile("OpiumUI.luau"))()

local Win = UI.Window{
    Title = "Opium",
    Subtitle = "demo",
    Width = 470,
    Height = 580,
    Position = UDim2.fromOffset(40, 40),
    ToggleKey = Enum.KeyCode.RightShift,
    Resizable = true,
}

-- Groups
local liveGroup = Win:TabGroup("Live")
local settingsGroup = Win:TabGroup("Settings")
local infoGroup = Win:TabGroup("Info")

-- Tabs
local dashboard = liveGroup:Tab("Dashboard")
local controls = settingsGroup:Tab("Controls")
local configTab = settingsGroup:Tab("Config")
local about = infoGroup:Tab("About")

-- Dashboard
local stats = dashboard:Section("Session")
local setFps = stats:Stat("FPS", "—")
local setUptime = stats:Stat("Uptime", "0:00")

local actions = dashboard:Section("Actions")
actions:Button("Reset", function()
    Win:Notify("Stats reset", { Type = "success" })
end)

-- Controls
local behavior = controls:Section("Behavior")
behavior:Toggle("Live stats", true, function(state)
    Win:Notify("Live stats: " .. (state and "on" or "off"))
end)

local sampling = controls:Section("Sampling")
sampling:Slider("Sample rate (ms)", 100, 1000, 500)

local appearance = controls:Section("Appearance")
appearance:Slider("UI scale (%)", 80, 120, 100)
appearance:Dropdown("Theme", {"Charcoal", "Slate"}, "Charcoal", function(value)
    Win:Notify("Theme: " .. value)
end)

-- Config
local profile = configTab:Section("Profile")
local name = profile:Input("Name", "profile name")
name:Set("default", true)

local persistence = configTab:Section("Persistence")
persistence:Button("Save", function()
    local ok, err = Win:SaveConfig("opium_config.json")
    Win:Notify(ok and "Saved" or ("Error: " .. tostring(err)), {
        Type = ok and "success" or "error",
    })
end)
persistence:Button("Load", function()
    local ok, err = Win:LoadConfig("opium_config.json")
    Win:Notify(ok and "Loaded" or ("Error: " .. tostring(err)), {
        Type = ok and "success" or "error",
    })
end)

-- About
local help = about:Section("Help")
help:Label("RightShift toggles the window.\nDrag the header to move.\nDrag the bottom-right corner to resize.")
about:Section("Session"):Button("Close", function()
    Win:SetVisible(false)
end)
```

> See `OpiumUI_Demo.luau` for a complete, runnable demo: live FPS/ping/memory stats, a sparkline, theme presets, config save/load and notifications.

---

## Notes and Limitations

- **Client-side.** OpiumUI creates `ScreenGui`s and reads `LocalPlayer`. It is not a server framework.
- **Notifications require a live window.** They are parented to the window's `ScreenGui` and are destroyed with it.
- **Dropdown outside-click** works with the mouse. On touch devices, close by selecting an option or tapping the header.
- **Slider precision.** No step parameter; values are floats. Round in your callback if needed.
- **No disabled state.** Controls are always interactive.
- **No built-in keybind component.** The window has `ToggleKey`, but individual keybind rows are not implemented.
- **No search or collapsible sections.** Sections can be hidden programmatically with `Section:SetVisible`.
- **Config keys depend on labels.** Renaming a tab, section or control changes its key.
- **One `ScreenGui` per window**, all named `OpiumUI`. Use `Win:Destroy()` to clean up.
- **`SetTheme` is a color remap.** It does not change fonts, corner radii or component sizes.
- **Executor APIs are optional.** Config functions degrade to `false, error` when `writefile` / `readfile` are unavailable.

---

## Roadmap

Ideas that fit the current design:

- `Keybind` component with capture and callback.
- Search/filter field for sections.
- Collapsible sections.
- Disabled state for controls.
- `Slider` step and suffix.
- `ColorPicker` wired to `SetTheme`.
- Tooltips.
- Modal / confirm dialog.
- Window state persistence (position and size).
- `Radio` and multi-select dropdowns.
