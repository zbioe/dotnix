--!nonstrict
-- Shortcuts panel: every mango bind with what it does, from the bind list itself.

local keys = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/keys.json") or "[]") or {}
local groupOrder = { "Apps", "System", "Windows", "Tags", "Screenshot", "Audio and brightness" }
local closeButton = true
local query = ""

local render

local modNames = { SUPER = "Super", SHIFT = "Shift", CTRL = "Ctrl", ALT = "Alt" }
local keyNames = {
  Return = "Enter",
  slash = "/",
  Print = "Print",
  Escape = "Esc",
  XF86AudioRaiseVolume = "Volume +",
  XF86AudioLowerVolume = "Volume −",
  XF86AudioMute = "Mute",
  XF86AudioMicMute = "Mic mute",
  XF86MonBrightnessUp = "Brightness +",
  XF86MonBrightnessDown = "Brightness −",
}

-- "SUPER+SHIFT,h" -> { "Super", "Shift", "H" }
local function caps(bind)
  local mods, key = bind:match("^([^,]*),(.*)$")
  local out = {}
  for mod in (mods or ""):gmatch("[^+]+") do
    if mod ~= "NONE" then table.insert(out, modNames[mod] or mod) end
  end
  key = keyNames[key] or (#key == 1 and key:upper() or key)
  table.insert(out, key)
  return out
end

local function keycap(text)
  return ui.row({ paddingH = 6, paddingV = 2, radius = 5, fill = "surface_variant", border = "outline/0.3", borderWidth = 1 }, {
    ui.label({ text = text, fontSize = 11, fontWeight = "bold" }),
  })
end

local function row(k)
  local chips = {}
  for i, c in ipairs(caps(k.key)) do
    if i > 1 then table.insert(chips, ui.label({ text = "+", fontSize = 10, color = "on_surface_variant" })) end
    table.insert(chips, keycap(c))
  end
  return ui.row({ key = k.group .. k.key, gap = 10, align = "center", paddingH = 8, paddingV = 4 }, {
    ui.row({ gap = 3, align = "center", width = 170 }, chips),
    ui.label({ text = k.desc, fontSize = 12, flexGrow = 1, maxLines = 2 }),
  })
end

local function matches(k, q)
  if q == "" then return true end
  local hay = (k.desc .. " " .. table.concat(caps(k.key), " ") .. " " .. k.group):lower()
  return hay:find(q, 1, true) ~= nil
end

render = function()
  local header = {
    ui.glyph({ name = "keyboard", size = 18, color = "primary" }),
    ui.label({ text = "Shortcuts", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
  }
  if closeButton then
    table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }))
  end

  local q = query:lower()
  local byGroup = {}
  for _, k in ipairs(keys) do
    if matches(k, q) then
      byGroup[k.group] = byGroup[k.group] or {}
      table.insert(byGroup[k.group], k)
    end
  end
  -- groups missing from groupOrder go last
  local order = table.clone(groupOrder)
  for group in pairs(byGroup) do
    if not table.find(order, group) then table.insert(order, group) end
  end

  local sections = {}
  for _, group in ipairs(order) do
    local list = byGroup[group]
    if list then
      local items = { ui.label({ text = group, fontSize = 12, fontWeight = "bold", color = "primary", paddingH = 4 }) }
      for _, k in ipairs(list) do table.insert(items, row(k)) end
      table.insert(sections, ui.column({ key = group, gap = 2, padding = 8, radius = 10, fill = "surface_variant/0.3" }, items))
    end
  end
  if #sections == 0 then
    table.insert(sections, ui.label({ text = "No shortcuts found", color = "on_surface_variant", textAlign = "center" }))
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 10 }, header),
    ui.input({
      key = "search",
      placeholder = "Search shortcuts…",
      controlSize = "sm",
      onChange = function(value)
        query = value
        render()
      end,
    }),
    ui.scroll({ flexGrow = 1, gap = 10 }, sections),
  }))
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  render()
end
