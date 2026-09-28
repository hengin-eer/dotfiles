local wezterm = require("wezterm")
local act = wezterm.action

-- Keep only terminal-emulator controls here. Herdr owns workspaces, tabs,
-- panes, copy mode, and the Ctrl+G leader.
return {
    keys = {
        { key = "Enter", mods = "ALT", action = act.ToggleFullScreen },
        { key = "c", mods = "SHIFT|CTRL", action = act.CopyTo("Clipboard") },
        { key = "v", mods = "SHIFT|CTRL", action = act.PasteFrom("Clipboard") },
        { key = "+", mods = "CTRL", action = act.IncreaseFontSize },
        { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
        { key = "0", mods = "CTRL", action = act.ResetFontSize },
        { key = "p", mods = "SHIFT|CTRL", action = act.ActivateCommandPalette },
        { key = "r", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
    },
}
