--!nonstrict
-- Updates panel for `flake-updates` (dotnix home/ui/flake-updates.nix): the
-- state of the last check, what moved, Check now / Apply, and the settings
-- (automatic checks, notifications, mode, interval, inputs on hold).
-- updates.json is built by Nix (home/ui/noctalia.nix) with the command's path.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/updates.json") or "{}") or {}
local st = nil -- `flake-updates status --json`
local closeButton = true
local running = false -- a check/apply started from here

local modes = { "notify", "ready", "auto" }
local modeLabels = { "Notify only", "Ready, 1 click", "Automatic" }
local modeHelp = {
  notify = "says which inputs have newer versions",
  ready = "builds them in the background; Apply when you want",
  auto = "builds and applies: home now, system at the next boot",
}
local intervals = { "daily", "weekly", "monthly" }
local intervalLabels = { "Every day", "Every week", "Every month" }

local render

local function indexOf(list, value)
  for i, v in ipairs(list) do
    if v == value then return i end
  end
  return 1
end

local function refresh()
  noctalia.runAsync({ data.command, "status", "--json" }, function(result)
    st = noctalia.json.decode(result.stdout or "") or st
    render()
  end)
end

local function set(key, value)
  noctalia.runAsync({ data.command, "set", key, value }, function(_result) refresh() end)
end

local function run(...)
  running = true
  render()
  noctalia.runAsync({ data.command, ... }, function(_result)
    running = false
    refresh()
  end)
end

local function busy()
  return running or (st ~= nil and st.phase ~= "idle")
end

local function ago(epoch)
  if not epoch or epoch == 0 then return "never checked" end
  local s = os.time() - epoch
  if s < 120 then return "checked just now" end
  if s < 7200 then return `checked {math.floor(s / 60)} min ago` end
  if s < 172800 then return `checked {math.floor(s / 3600)} h ago` end
  return `checked {math.floor(s / 86400)} days ago`
end

-- glyph, color, title of the state card
local function headline()
  if st == nil then return "loader-2", "on_surface_variant", "Reading…" end
  if st.phase == "building" then return "hammer", "primary", "Building the update…" end
  if st.phase == "checking" or running then return "refresh", "primary", "Checking…" end
  local n = #st.changes
  local r = st.result
  if r == "up-to-date" then return "circle-check", "primary", "Up to date" end
  if r == "ready" then return "package", "primary", `Update ready · {n} input{n == 1 and "" or "s"}` end
  if r == "available" then return "bell", "primary", `{n} input{n == 1 and "" or "s"} with updates` end
  if r == "failed" then return "alert-triangle", "error", "The update doesn't build yet" end
  if r == "pending-boot" then return "power", "primary", "Applied · system at the next boot" end
  if r == "applying" then return "loader-2", "primary", "Applying…" end
  if r == "offline" then return "wifi-off", "on_surface_variant", "Couldn't check (offline?)" end
  return "clock", "on_surface_variant", "Not checked yet"
end

local function card(children)
  return ui.column({ gap = 10, padding = 12, radius = 12, fill = "surface_variant/0.5" }, children)
end

local function settingRow(title, help, control)
  return ui.row({ gap = 10, align = "center" }, {
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = title, fontSize = 12, fontWeight = "medium" }),
      ui.label({ text = help, fontSize = 10, color = "on_surface_variant", maxLines = 2 }),
    }),
    control,
  })
end

local function changeRows()
  local rows = {}
  for _, c in ipairs(st.changes) do
    table.insert(rows, ui.row({ key = c.name, gap = 8, align = "center" }, {
      ui.glyph({ name = "arrow-up-circle", size = 14, color = "primary" }),
      ui.label({ text = c.name, fontSize = 12, fontWeight = "medium", flexGrow = 1 }),
      ui.label({ text = `{c.from} → {c.to}`, fontSize = 10, color = "on_surface_variant" }),
      ui.label({ text = `+{c.days}d`, fontSize = 10, color = "primary", width = 34, textAlign = "end" }),
    }))
  end
  return rows
end

local function holdRows()
  local held = {}
  for _, h in ipairs(st.hold) do held[h] = true end
  local rows = {}
  for _, name in ipairs(st.inputs) do
    table.insert(rows, ui.row({ key = "hold-" .. name, gap = 8, align = "center" }, {
      ui.label({ text = name, fontSize = 11, flexGrow = 1, color = held[name] and "on_surface_variant" or "on_surface" }),
      ui.label({ text = held[name] and "on hold" or "updates", fontSize = 10, color = "on_surface_variant" }),
      ui.toggle({ checked = not held[name], enabled = not busy(), onChange = function(v)
        local list = {}
        for _, other in ipairs(st.inputs) do
          local keep = held[other]
          if other == name then keep = not (v == true or v == "true") end
          if keep then table.insert(list, other) end
        end
        set("hold", table.concat(list, " "))
      end }),
    }))
  end
  return rows
end

render = function()
  local header = {
    ui.glyph({ name = "package", size = 18, color = "primary" }),
    ui.label({ text = "Updates", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
  }
  if closeButton then
    table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }))
  end

  local glyph, color, title = headline()
  local stateCard = {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = glyph, size = 22, color = color }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = title, fontSize = 13, fontWeight = "bold", color = color }),
        ui.label({ text = st and ago(st.lastCheck) or "", fontSize = 10, color = "on_surface_variant" }),
      }),
    }),
  }
  if st and #st.changes > 0 then
    for _, row in ipairs(changeRows()) do table.insert(stateCard, row) end
  end
  table.insert(stateCard, ui.row({ gap = 8 }, {
    ui.button({ text = "Check now", glyph = "refresh", variant = "outline", controlSize = "sm", flexGrow = 1,
      enabled = not busy(), onClick = function() run("check") end }),
    ui.button({ text = "Apply", glyph = "download", variant = "primary", controlSize = "sm", flexGrow = 1,
      visible = st ~= nil and st.result == "ready", enabled = not busy(),
      onClick = function() run("apply") end }),
    ui.button({ glyph = "file-text", variant = "ghost", controlSize = "sm", tooltip = "Log",
      onClick = function() noctalia.runAsync({ "foot", "--title=Updates log", "sh", "-c", data.command .. " log; read -r _" }, function(_r) end) end }),
  }))

  local body = { ui.row({ align = "center", gap = 10 }, header), card(stateCard) }

  -- deprecations: fine now, errors in a later release (`flake-updates log`)
  if st and st.warnings and #st.warnings > 0 then
    local n = #st.warnings
    table.insert(body, ui.row({ gap = 10, align = "center", padding = 10, radius = 12, fill = "error/0.12",
      tooltip = table.concat(st.warnings, "\n") }, {
      ui.glyph({ name = "alert-circle", size = 16, color = "error" }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = `{n} deprecation warning{n == 1 and "" or "s"}`, fontSize = 12, fontWeight = "medium" }),
        ui.label({ text = "still builds; fix before a release turns them into errors", fontSize = 10,
          color = "on_surface_variant", maxLines = 2 }),
      }),
    }))
  end

  if st then
    table.insert(body, card({
      settingRow("Automatic checks", "look for updates on their own", ui.toggle({ checked = st.enabled,
        onChange = function(v) set("enabled", (v == true or v == "true") and "on" or "off") end })),
      settingRow("Notifications", "tell when something is ready or applied", ui.toggle({ checked = st.notify,
        onChange = function(v) set("notify", (v == true or v == "true") and "on" or "off") end })),
      settingRow("Mode", modeHelp[st.mode] or "", ui.select({ options = modeLabels, width = 150, controlSize = "sm",
        selectedIndex = indexOf(modes, st.mode) - 1,
        onChange = function(i) set("mode", modes[(tonumber(i) or 0) + 1]) end })),
      settingRow("Check", "how often (when automatic checks are on)", ui.select({ options = intervalLabels, width = 150,
        controlSize = "sm", selectedIndex = indexOf(intervals, st.interval) - 1,
        onChange = function(i) set("interval", intervals[(tonumber(i) or 0) + 1]) end })),
    }))
    table.insert(body, ui.label({ text = "Inputs · off keeps one where it is", fontSize = 11,
      color = "on_surface_variant", paddingH = 4 }))
    table.insert(body, ui.scroll({ flexGrow = 1, gap = 6, padding = 10, radius = 12, fill = "surface_variant/0.3" }, holdRows()))
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, body))
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  render()
  refresh()
  panel.setWantsSecondTicks(true)
end

-- follow a check running in the background (timer or this panel)
local ticks = 0
function update()
  ticks += 1
  if busy() and ticks % 2 == 0 then refresh() end
end
