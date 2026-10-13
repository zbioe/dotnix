--!nonstrict
-- Control center tile: shows the active theme and opens the theme panel.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/themes.json") or "{}") or {}

local function render()
  local raw = noctalia.readFile(data.state .. "/name")
  shortcut.setLabel(raw and (raw:gsub("%s+$", "")) or "Theme")
  shortcut.setIcon("palette")
  shortcut.setActive(false)
  shortcut.setEnabled(true)
end

render()

function onClick()
  noctalia.togglePanel("dotnix/theme:picker")
end

function update()
  render()
end
