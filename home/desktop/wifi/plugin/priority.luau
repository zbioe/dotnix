--!nonstrict
-- Wi-Fi priority panel for `wifi-prefer`: the saved networks in order.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/wifi.json") or "{}") or {}
local networks = {} -- { prio, uuid, name, ssid, active, signal }
local enabled = true
local closeButton = true
local busy = false

local render

local function split(line)
  local fields = {}
  for field in (line .. "\t"):gmatch("([^\t]*)\t") do
    table.insert(fields, field)
  end
  return fields
end

-- reads `wifi-prefer status` and `wifi-prefer list`, then redraws
local function refresh()
  noctalia.runAsync({ data.command, "status" }, function(result)
    enabled = (result.stdout or ""):match("^on") ~= nil
    noctalia.runAsync({ data.command, "list" }, function(listed)
      networks = {}
      for line in (listed.stdout or ""):gmatch("[^\n]+") do
        local f = split(line)
        table.insert(networks, {
          prio = tonumber(f[1]) or 0,
          uuid = f[2],
          name = f[3],
          ssid = f[4],
          active = f[5] == "yes",
          signal = tonumber(f[6]) or 0,
        })
      end
      busy = false
      render()
    end)
  end)
end

local function run(...)
  busy = true
  render()
  noctalia.runAsync({ data.command, ... }, function(_result)
    refresh()
  end)
end

-- swaps network i with its neighbour (delta -1 up, +1 down) and saves the order
local function move(i, delta)
  local j = i + delta
  if j < 1 or j > #networks then
    return
  end
  networks[i], networks[j] = networks[j], networks[i]
  local argv = { "order" }
  for _, n in ipairs(networks) do
    table.insert(argv, n.uuid)
  end
  run(table.unpack(argv))
end

local function signalGlyph(n)
  if n.signal <= 0 then
    return "wifi-off"
  end
  if n.signal >= 75 then
    return "wifi"
  end
  if n.signal >= 50 then
    return "wifi-2"
  end
  if n.signal >= 25 then
    return "wifi-1"
  end
  return "wifi-0"
end

local function row(i, n)
  local detail = n.signal > 0 and `{n.signal}%` or "out of range"
  if n.active then
    detail = "connected · " .. detail
  end
  return ui.row({
    key = n.uuid,
    gap = 8,
    align = "center",
    padding = 8,
    radius = 10,
    fill = n.active and "primary/0.15" or "surface_variant/0.3",
    border = n.active and "primary" or "outline/0.2",
    borderWidth = 1,
  }, {
    ui.label({ text = tostring(i), fontSize = 11, color = "on_surface_variant", width = 14 }),
    ui.glyph({ name = signalGlyph(n), size = 16, color = n.signal > 0 and "on_surface" or "on_surface_variant" }),
    ui.column({ gap = 0, flexGrow = 1 }, {
      ui.label({ text = n.name, fontSize = 12, fontWeight = n.active and "bold" or "medium", maxLines = 1 }),
      ui.label({ text = detail, fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.button({
      glyph = "chevron-up",
      variant = "ghost",
      controlSize = "sm",
      tooltip = "Higher priority",
      enabled = i > 1 and not busy,
      onClick = function()
        move(i, -1)
      end,
    }),
    ui.button({
      glyph = "chevron-down",
      variant = "ghost",
      controlSize = "sm",
      tooltip = "Lower priority",
      enabled = i < #networks and not busy,
      onClick = function()
        move(i, 1)
      end,
    }),
  })
end

render = function()
  local header = {
    ui.glyph({ name = "wifi", size = 18, color = "primary" }),
    ui.label({ text = "Wi-Fi Priority", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
  }
  if closeButton then
    table.insert(
      header,
      ui.button({
        glyph = "close",
        variant = "ghost",
        controlSize = "sm",
        onClick = function()
          panel.close()
        end,
      })
    )
  end

  local rows = {}
  for i, n in ipairs(networks) do
    table.insert(rows, row(i, n))
  end
  if #rows == 0 then
    table.insert(
      rows,
      ui.label({ text = "No saved Wi-Fi networks", color = "on_surface_variant", textAlign = "center" })
    )
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 10 }, header),
    ui.row({ gap = 10, align = "center", padding = 10, radius = 12, fill = "surface_variant/0.5" }, {
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = "Prefer higher networks", fontSize = 12, fontWeight = "medium" }),
        ui.label({ text = "switches when one above is in range", fontSize = 10, color = "on_surface_variant" }),
      }),
      ui.toggle({
        checked = enabled,
        enabled = not busy,
        onChange = function(v)
          run((v == true or v == "true") and "on" or "off")
        end,
      }),
    }),
    ui.label({ text = "Top of the list wins", fontSize = 11, color = "on_surface_variant", paddingH = 4 }),
    ui.scroll({ flexGrow = 1, gap = 6 }, rows),
  }))
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  render()
  refresh()
  -- signal and connection changes while open
  panel.setWantsSecondTicks(true)
end

local ticks = 0
function update()
  ticks += 1
  if ticks % 5 == 0 and not busy then
    refresh()
  end
end
