--!nonstrict
-- VPN bar widget for `vpn` (dotnix home/ui/vpn.nix): a shield, lit while a
-- VPN is up. Left click opens the panel (manifest), right click toggles it.
-- vpn.json is built by Nix (home/ui/noctalia.nix) with the command's path.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/vpn.json") or "{}") or {}
local busy = false

local function show(st)
  local active = st and st.active or {}
  if #active > 0 then
    barWidget.setGlyph("shield-check")
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip(`VPN: {active[1].name} (right click: disconnect)`)
  else
    barWidget.setGlyph("shield-off")
    barWidget.setGlyphColor("on_surface")
    barWidget.setTooltip("VPN off (right click: connect)")
  end
end

local function refresh()
  noctalia.runAsync({ data.command, "status", "--json" }, function(result)
    if not busy then show(noctalia.json.decode(result.stdout or "")) end
  end)
end

function update()
  noctalia.setUpdateInterval(3000)
  refresh()
end

function onRightClick()
  if busy then return end
  busy = true
  barWidget.setGlyph("loader-2")
  noctalia.runAsync({ data.command, "toggle" }, function(_result)
    busy = false
    refresh()
  end)
end
