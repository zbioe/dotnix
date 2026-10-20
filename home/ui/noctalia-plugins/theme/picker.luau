--!nonstrict
-- Theme panel for `theme` (dotnix home/theme): every theme with its colors,
-- light/dark and the day/night schedule. themes.json is built by Nix
-- (home/ui/noctalia.nix); changes run the `theme` command, which switches the
-- whole system (and this panel's palette) live.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/themes.json") or "{}") or {}
local current = { name = "", mode = "dark", auto = false, sun = "" }
local closeButton = true
local hover = nil -- theme name under the pointer
local query = "" -- search filter

local function readState(file)
  local raw = noctalia.readFile(data.state .. "/" .. file)
  return raw and (raw:gsub("%s+$", "")) or ""
end

local function refresh()
  current.name = readState("name")
  current.mode = readState("mode")
  current.auto = readState("auto") == "on"
  current.sun = readState("sun")
end

local render

-- "HH:MM HH:MM" from `theme auto-tick` (sunrise/sunset at the current position)
local function sunText()
  local rise, set = current.sun:match("^(%S+)%s+(%S+)$")
  if not rise then return "light by day · dark at night" end
  return `light at {rise} · dark at {set}`
end

-- runs `theme ARGS...` (argv, no shell) and redraws with the new state
local function theme(...)
  local argv = { data.theme, ... }
  noctalia.runAsync(argv, function(_result)
    refresh()
    render()
  end)
end

-- segmented Light / Dark / Auto; `theme mode` also ends the schedule
local function modeButton(label, glyph, active, onClick)
  return ui.button({
    text = label,
    glyph = glyph,
    variant = active and "primary" or "ghost",
    controlSize = "sm",
    flexGrow = 1,
    onClick = onClick,
  })
end

local function modeSwitch()
  return ui.row({ gap = 4, padding = 4, radius = 12, fill = "surface_variant/0.5" }, {
    modeButton("Light", "sun", not current.auto and current.mode == "light", function() theme("mode", "light") end),
    modeButton("Dark", "moon", not current.auto and current.mode == "dark", function() theme("mode", "dark") end),
    modeButton("Auto", "clock", current.auto, function() theme("auto", "on") end),
  })
end

-- "catppuccin-macchiato" -> "Catppuccin Macchiato"
local function title(name)
  return (name:gsub("-", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

-- a few lines of fake code in the theme's own colors; swatches are
-- base00 base05 base08 base0A base0B base0D base0E (home/ui/noctalia.nix)
local function preview(c)
  local bg, fg, red, yellow, green, blue, magenta = c[1], c[2], c[3], c[4], c[5], c[6], c[7]
  local function tok(w, color) return ui.box({ width = w, height = 5, radius = 2.5, fill = color }) end
  local function line(indent, tokens)
    local items = { ui.box({ width = indent, height = 5 }) }
    for _, t in ipairs(tokens) do table.insert(items, t) end
    return ui.row({ gap = 4, align = "center" }, items)
  end
  return ui.column({ gap = 6, padding = 10, radius = 8, fill = bg, border = fg .. "22", borderWidth = 1 }, {
    line(0, { tok(16, magenta), tok(30, blue), tok(12, fg) }),
    line(10, { tok(14, yellow), tok(36, green) }),
    line(10, { tok(22, fg), tok(10, red), tok(18, blue) }),
    line(0, { tok(54, fg .. "55") }),
  })
end

local function card(entry)
  local active = entry.name == current.name
  local hovered = entry.name == hover
  return ui.column({
    key = entry.name,
    flexGrow = 1,
    gap = 8,
    padding = 6,
    radius = 12,
    fill = active and "primary/0.15" or (hovered and "surface_variant/0.6" or "surface_variant/0.2"),
    border = active and "primary" or (hovered and "outline/0.6" or "outline/0.2"),
    borderWidth = active and 2 or 1,
    tooltip = entry.name,
    onClick = function() theme("set", entry.name) end,
    onHover = function(state)
      hover = state == "true" and entry.name or (hover ~= entry.name and hover or nil)
      render()
    end,
  }, {
    preview(entry[current.mode] or entry.dark or entry.light),
    ui.row({ gap = 6, align = "center", paddingH = 2 }, {
      ui.label({
        text = title(entry.name),
        fontSize = 12,
        fontWeight = active and "bold" or "medium",
        color = active and "primary" or "on_surface",
        maxLines = 1,
        flexGrow = 1,
      }),
      ui.glyph({ name = "circle-check-filled", size = 14, color = "primary", visible = active }),
    }),
  })
end

local function grid(entries)
  local rows = {}
  for i = 1, #entries, 2 do
    local right = entries[i + 1] and card(entries[i + 1]) or ui.spacer({ flexGrow = 1 })
    table.insert(rows, ui.row({ gap = 10 }, { card(entries[i]), right }))
  end
  if #rows == 0 then
    table.insert(rows, ui.label({ text = "No themes found", color = "on_surface_variant", textAlign = "center" }))
  end
  return rows
end

render = function()
  local header = {
    ui.glyph({ name = "palette", size = 18, color = "primary" }),
    ui.column({ gap = 0, flexGrow = 1 }, {
      ui.label({ text = "Themes", fontSize = 16, fontWeight = "bold" }),
      ui.label({ text = current.name ~= "" and title(current.name) or "—", fontSize = 11, color = "on_surface_variant" }),
    }),
  }
  table.insert(header, ui.button({
    glyph = "typography",
    variant = "ghost",
    controlSize = "sm",
    tooltip = "Fonts",
    onClick = function() noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "dotnix/theme:fonts" }, function(_r) end) end,
  }))
  if closeButton then
    table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }))
  end

  local q = query:lower()
  local entries = {}
  for _, entry in ipairs(data.themes or {}) do
    if q == "" or entry.name:lower():find(q, 1, true) then
      table.insert(entries, entry)
    end
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 10 }, header),
    modeSwitch(),
    ui.row({ gap = 6, align = "center", paddingH = 4, visible = current.auto }, {
      ui.glyph({ name = "sun-moon", size = 14, color = "on_surface_variant" }),
      ui.label({ text = sunText(), fontSize = 11, color = "on_surface_variant" }),
    }),
    ui.input({
      key = "search",
      placeholder = "Search themes…",
      controlSize = "sm",
      onChange = function(value)
        query = value
        render()
      end,
    }),
    ui.scroll({ flexGrow = 1, gap = 10, revealKey = current.name }, grid(entries)),
  }))
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  refresh()
  render()
  -- follow changes made elsewhere (bar toggle, schedule, terminal)
  panel.setWantsSecondTicks(true)
end

function update()
  local before = current.name .. current.mode .. tostring(current.auto) .. current.sun
  refresh()
  if before ~= current.name .. current.mode .. tostring(current.auto) .. current.sun then
    render()
  end
end
