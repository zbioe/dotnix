--!nonstrict
-- VPN panel for `vpn`: what is connected, quick connections, saved WireGuard files.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/vpn.json") or "{}") or {}
local st = nil -- `vpn status --json`
local closeButton = true
local busy = false
local newTarget = ""

local render

local countries = {
  AR = "Argentina",
  AU = "Australia",
  BR = "Brazil",
  CA = "Canada",
  CH = "Switzerland",
  DE = "Germany",
  ES = "Spain",
  FR = "France",
  GB = "United Kingdom",
  IT = "Italy",
  JP = "Japan",
  MX = "Mexico",
  NL = "Netherlands",
  PT = "Portugal",
  SE = "Sweden",
  SG = "Singapore",
  US = "United States",
}

local function flag(code)
  return utf8.char(0x1F1E6 + code:byte(1) - 65, 0x1F1E6 + code:byte(2) - 65)
end

-- glyph (or flag), title and detail of a target
local function describe(target)
  if target == "fastest" then
    return "bolt", nil, "Fastest server", "the quickest one right now"
  end
  if target == "securecore" then
    return "shield-lock", nil, "Secure Core", "through a privacy-friendly country"
  end
  if target == "p2p" then
    return "arrows-exchange", nil, "P2P", "fastest server for file sharing"
  end
  if target == "tor" then
    return "spy", nil, "Tor", "Tor over VPN"
  end
  local city = target:match("^city:(.+)$")
  if city then
    return "building", nil, city, "fastest server in the city"
  end
  local code = target:upper():match("^(%a%a)$")
  if code then
    return nil, flag(code), countries[code] or code, "fastest server in " .. code
  end
  local server = target:upper():match("^(%a%a)#%d+$")
  if server then
    return nil, flag(server), target:upper(), "this server"
  end
  return "shield", nil, target, "WireGuard"
end

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
  noctalia.runAsync({ data.command, ... }, function(_result)
    refresh()
  end)
end

local function activeName()
  local active = st and st.active or {}
  return active[1] and active[1].name or nil
end

-- the favorite the current connection came from
local function isActive(target)
  local name = activeName()
  if not name then
    return false
  end
  local server = name:match("^ProtonVPN (%a%a#%d+)")
  if server then
    local t = target:upper()
    if t == server or t == server:sub(1, 2) then
      return true
    end
  end
  return target == st.last or target == name
end

local function card(children)
  return ui.row({ gap = 10, align = "center", padding = 12, radius = 12, fill = "surface_variant/0.5" }, children)
end

local function stateCard()
  if st == nil then
    return card({
      ui.glyph({ name = "loader-2", size = 22, color = "on_surface_variant" }),
      ui.label({ text = "Reading…", flexGrow = 1 }),
    })
  end
  local name = activeName()
  if name then
    return card({
      ui.glyph({ name = "shield-check", size = 22, color = "primary" }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = name:gsub("^ProtonVPN ", ""), fontSize = 13, fontWeight = "bold", maxLines = 1 }),
        ui.label({ text = "connected", fontSize = 10, color = "on_surface_variant" }),
      }),
      ui.button({
        text = "Disconnect",
        glyph = "plug-x",
        enabled = not busy,
        onClick = function()
          run("down")
        end,
      }),
    })
  end
  local _, _, title = describe(st.last ~= "" and st.last or "fastest")
  return card({
    ui.glyph({ name = "shield-off", size = 22, color = "on_surface_variant" }),
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = busy and "Connecting…" or "Not connected", fontSize = 13, fontWeight = "bold" }),
      ui.label({ text = "Connect: " .. title, fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.button({
      text = "Connect",
      glyph = "plug-connected",
      enabled = not busy,
      onClick = function()
        run("up")
      end,
    }),
  })
end

local function targetRow(target, removable, removeArgs)
  local glyph, emoji, title, detail = describe(target)
  local active = isActive(target)
  local icon = emoji and ui.label({ text = emoji, fontSize = 16, width = 20 })
    or ui.glyph({ name = glyph, size = 16, color = active and "primary" or "on_surface" })
  local children = {
    icon,
    ui.column({ gap = 0, flexGrow = 1 }, {
      ui.label({ text = title, fontSize = 12, fontWeight = active and "bold" or "medium", maxLines = 1 }),
      ui.label({ text = detail, fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
    }),
    active and ui.button({
      glyph = "plug-x",
      variant = "ghost",
      controlSize = "sm",
      tooltip = "Disconnect",
      enabled = not busy,
      onClick = function()
        run("down")
      end,
    }) or ui.button({
      glyph = "plug-connected",
      variant = "ghost",
      controlSize = "sm",
      tooltip = "Connect",
      enabled = not busy,
      onClick = function()
        run("up", target)
      end,
    }),
  }
  if removable then
    table.insert(
      children,
      ui.button({
        glyph = "trash",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Remove",
        enabled = not busy and not active,
        onClick = function()
          run(table.unpack(removeArgs))
        end,
      })
    )
  end
  return ui.row({
    key = target,
    gap = 8,
    align = "center",
    padding = 8,
    radius = 10,
    fill = active and "primary/0.15" or "surface_variant/0.3",
    border = active and "primary" or "outline/0.2",
    borderWidth = 1,
  }, children)
end

local function section(title)
  return ui.label({ text = title, fontSize = 11, color = "on_surface_variant", paddingH = 4 })
end

render = function()
  local header = {
    ui.glyph({ name = "shield", size = 18, color = "primary" }),
    ui.label({ text = "VPN", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
  }
  if st and st.proton then
    table.insert(
      header,
      ui.button({
        glyph = "external-link",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Proton VPN app: every server and the settings",
        onClick = function()
          noctalia.runAsync({ data.command, "app" })
          panel.close()
        end,
      })
    )
  end
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
  if st and st.proton then
    table.insert(rows, section("Quick connect"))
    for _, target in ipairs(st.favorites) do
      table.insert(rows, targetRow(target, true, { "fav", "remove", target }))
    end
    table.insert(
      rows,
      ui.row({ gap = 8, align = "center" }, {
        ui.input({
          key = "new-target",
          placeholder = "Country (DE), server (BR#10), city:Tokyo…",
          controlSize = "sm",
          flexGrow = 1,
          onChange = function(value)
            newTarget = value
          end,
        }),
        ui.button({
          text = "Add",
          glyph = "plus",
          controlSize = "sm",
          enabled = not busy,
          onClick = function()
            local target = newTarget:gsub("^%s+", ""):gsub("%s+$", "")
            if target ~= "" then
              run("fav", "add", target)
            end
          end,
        }),
      })
    )
  end
  local saved = st and st.saved or {}
  if #saved > 0 then
    table.insert(rows, section("WireGuard files"))
    for _, c in ipairs(saved) do
      table.insert(rows, targetRow(c.name, true, { "remove", c.uuid }))
    end
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 10 }, header),
    stateCard(),
    ui.scroll({ flexGrow = 1, gap = 6 }, rows),
    ui.label({
      text = "Add a WireGuard file: vpn add FILE.conf",
      fontSize = 10,
      color = "on_surface_variant",
      paddingH = 4,
    }),
  }))
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
  if ticks % 3 == 0 and not busy then
    refresh()
  end
end
