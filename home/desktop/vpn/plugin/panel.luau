--!nonstrict
-- VPN panel for `vpn`: what is connected, the saved connections, the Proton app.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/vpn.json") or "{}") or {}
local st = nil -- `vpn status --json`
local closeButton = true
local busy = false

local render

local function refresh()
  noctalia.runAsync({ data.command, "status", "--json" }, function(result)
    st = noctalia.json.decode(result.stdout or "") or st
    busy = false
    render()
  end)
end

local function run(...)
  busy = true
  render()
  noctalia.runAsync({ data.command, ... }, function(_result) refresh() end)
end

local function card(children)
  return ui.row({ gap = 10, align = "center", padding = 12, radius = 12, fill = "surface_variant/0.5" }, children)
end

local function stateCard()
  local active = st and st.active or {}
  if st == nil then
    return card({ ui.glyph({ name = "loader-2", size = 22, color = "on_surface_variant" }),
      ui.label({ text = "Reading…", flexGrow = 1 }) })
  end
  if #active > 0 then
    return card({
      ui.glyph({ name = "shield-check", size = 22, color = "primary" }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = active[1].name, fontSize = 13, fontWeight = "bold", maxLines = 1 }),
        ui.label({ text = "connected", fontSize = 10, color = "on_surface_variant" }),
      }),
      ui.button({ text = "Disconnect", glyph = "plug-x", enabled = not busy, onClick = function() run("down") end }),
    })
  end
  local last = nil
  for _, c in ipairs(st.saved) do
    if c.uuid == st.last then last = c end
  end
  return card({
    ui.glyph({ name = "shield-off", size = 22, color = "on_surface_variant" }),
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = "Not connected", fontSize = 13, fontWeight = "bold" }),
      ui.label({ text = last and `last: {last.name}` or "pick a server below", fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.button({ text = "Connect", glyph = "plug-connected", enabled = not busy and (last ~= nil or st.app),
      onClick = function() run("up") end }),
  })
end

local function savedRow(c)
  return ui.row({
    key = c.uuid,
    gap = 8,
    align = "center",
    padding = 8,
    radius = 10,
    fill = c.active and "primary/0.15" or "surface_variant/0.3",
    border = c.active and "primary" or "outline/0.2",
    borderWidth = 1,
  }, {
    ui.glyph({ name = c.active and "shield-check" or "shield", size = 16, color = c.active and "primary" or "on_surface" }),
    ui.column({ gap = 0, flexGrow = 1 }, {
      ui.label({ text = c.name, fontSize = 12, fontWeight = c.active and "bold" or "medium", maxLines = 1 }),
      ui.label({ text = c.type == "wireguard" and "WireGuard" or "VPN", fontSize = 10, color = "on_surface_variant" }),
    }),
    c.active and ui.button({ glyph = "plug-x", variant = "ghost", controlSize = "sm", tooltip = "Disconnect",
        enabled = not busy, onClick = function() run("down") end })
      or ui.button({ glyph = "plug-connected", variant = "ghost", controlSize = "sm", tooltip = "Connect",
        enabled = not busy, onClick = function() run("up", c.uuid) end }),
    ui.button({ glyph = "trash", variant = "ghost", controlSize = "sm", tooltip = "Remove",
      enabled = not busy and not c.active, onClick = function() run("remove", c.uuid) end }),
  })
end

render = function()
  local header = {
    ui.glyph({ name = "shield", size = 18, color = "primary" }),
    ui.label({ text = "VPN", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
  }
  if closeButton then
    table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }))
  end

  local body = {
    ui.row({ align = "center", gap = 10 }, header),
    stateCard(),
  }

  if st and st.app then
    table.insert(body, card({
      ui.glyph({ name = "world", size = 20, color = "on_surface" }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = "Proton VPN", fontSize = 12, fontWeight = "medium" }),
        ui.label({ text = "every server: fastest, by country, Secure Core", fontSize = 10, color = "on_surface_variant" }),
      }),
      ui.button({ text = "Open", glyph = "external-link", onClick = function()
        noctalia.runAsync({ data.command, "app" })
        panel.close()
      end }),
    }))
  end

  local rows = {}
  for _, c in ipairs(st and st.saved or {}) do table.insert(rows, savedRow(c)) end
  if #rows == 0 then
    table.insert(rows, ui.label({ text = "None saved yet", color = "on_surface_variant", textAlign = "center" }))
  end
  table.insert(body, ui.label({ text = "Saved", fontSize = 11, color = "on_surface_variant", paddingH = 4 }))
  table.insert(body, ui.scroll({ flexGrow = 1, gap = 6 }, rows))
  table.insert(body, ui.label({ text = "Add a WireGuard file: vpn add FILE.conf", fontSize = 10, color = "on_surface_variant", paddingH = 4 }))

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, body))
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  render()
  refresh()
  panel.setWantsSecondTicks(true)
end

local ticks = 0
function update()
  ticks += 1
  if ticks % 3 == 0 and not busy then refresh() end
end
