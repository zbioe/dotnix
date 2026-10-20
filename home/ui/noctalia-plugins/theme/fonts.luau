--!nonstrict
-- Font panel for `theme font` (dotnix home/theme/fonts): the family of each
-- role, the sizes and the presets. fonts.json is built by Nix
-- (home/ui/noctalia.nix); every change runs `theme font`, which applies live.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/fonts.json") or "{}") or {}
local current = {}
local closeButton = true

local roles = {
  { key = "ui", label = "Interface", list = "ui" },
  { key = "serif", label = "Serif", list = "serif" },
  { key = "mono", label = "Monospace", list = "mono" },
  { key = "term", label = "Terminal", list = "mono" },
  { key = "emoji", label = "Emoji", list = "emoji" },
}
local sizes = {
  { key = "ui", label = "Interface" },
  { key = "mono", label = "Monospace" },
  { key = "term", label = "Terminal" },
  { key = "editor", label = "Emacs" },
}

local render

-- the state file over the defaults ("key=value" lines)
local function refresh()
  current = {}
  for k, v in pairs(data.default or {}) do current[k] = v end
  local raw = noctalia.readFile(data.state .. "/font/state") or ""
  for k, v in raw:gmatch("([%w_]+)=([^\n]*)") do current[k] = v end
end

-- runs `theme font ARGS...` (argv, no shell) and redraws with the new state
local function font(...)
  noctalia.runAsync({ data.theme, "font", ... }, function(_result)
    refresh()
    render()
  end)
end

local function indexOf(list, value)
  for i, v in ipairs(list) do
    if v == value then return i - 1 end
  end
  return 0
end

local function roleRow(role)
  local list = data.roles[role.list] or {}
  return ui.row({ gap = 10, align = "center" }, {
    ui.label({ text = role.label, fontSize = 12, color = "on_surface_variant", width = 84 }),
    ui.select({
      key = "role-" .. role.key,
      options = list,
      selectedIndex = indexOf(list, current[role.key]),
      controlSize = "sm",
      flexGrow = 1,
      onChange = function(_index, text)
        if text ~= current[role.key] then font(role.key, text) end
      end,
    }),
  })
end

local function sizeRow(size)
  return ui.row({ gap = 6, align = "center" }, {
    ui.label({ text = size.label, fontSize = 12, color = "on_surface_variant", flexGrow = 1 }),
    ui.button({ glyph = "minus", variant = "ghost", controlSize = "sm", onClick = function() font("size", size.key, "-1") end }),
    ui.label({ text = current[size.key .. "_size"] or "", fontSize = 13, fontWeight = "bold", width = 36, textAlign = "center" }),
    ui.button({ glyph = "plus", variant = "ghost", controlSize = "sm", onClick = function() font("size", size.key, "+1") end }),
  })
end

local function section(title, children)
  return ui.column({ gap = 8, padding = 10, radius = 12, fill = "surface_variant/0.3" }, {
    ui.label({ text = title, fontSize = 11, fontWeight = "bold", color = "on_surface_variant" }),
    ui.column({ gap = 6 }, children),
  })
end

render = function()
  local header = {
    ui.glyph({ name = "typography", size = 18, color = "primary" }),
    ui.column({ gap = 0, flexGrow = 1 }, {
      ui.label({ text = "Fonts", fontSize = 16, fontWeight = "bold" }),
      ui.label({ text = (current.ui or "") .. " · " .. (current.term or ""), fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
    }),
  }
  if closeButton then
    table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }))
  end

  local families = {}
  for _, role in ipairs(roles) do table.insert(families, roleRow(role)) end
  local sizeRows = {
    ui.row({ gap = 6 }, {
      ui.button({ text = "Smaller", glyph = "minus", variant = "ghost", controlSize = "sm", flexGrow = 1, onClick = function() font("size", "-1") end }),
      ui.button({ text = "Larger", glyph = "plus", variant = "ghost", controlSize = "sm", flexGrow = 1, onClick = function() font("size", "+1") end }),
    }),
  }
  for _, size in ipairs(sizes) do table.insert(sizeRows, sizeRow(size)) end

  -- three presets a row
  local presets, row = {}, {}
  for i, name in ipairs(data.presets or {}) do
    table.insert(row, ui.button({ text = name, variant = "ghost", controlSize = "sm", flexGrow = 1, onClick = function() font("preset", name) end }))
    if #row == 3 or i == #data.presets then
      table.insert(presets, ui.row({ gap = 4 }, row))
      row = {}
    end
  end
  table.insert(presets, ui.button({ text = "Back to the defaults", glyph = "restore", variant = "ghost", controlSize = "sm", onClick = function() font("reset") end }))

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 10 }, header),
    ui.scroll({ flexGrow = 1, gap = 12 }, {
      section("Families", families),
      section("Sizes (pt)", sizeRows),
      section("Presets", presets),
      ui.label({
        text = "Terminals already open keep their font (foot, LibreWolf too: on their next start).",
        fontSize = 11,
        color = "on_surface_variant",
      }),
    }),
  }))
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  refresh()
  render()
  -- follow changes made elsewhere (terminal)
  panel.setWantsSecondTicks(true)
end

function update()
  local before = noctalia.json.encode(current)
  refresh()
  if before ~= noctalia.json.encode(current) then render() end
end
