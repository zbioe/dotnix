--!nonstrict
-- Font panel for `theme font` (dotnix home/theme/fonts): one tab per role
-- with a live preview, every family written in itself, the sizes and the
-- presets. fonts.json is built by Nix (home/ui/noctalia.nix); every change
-- runs `theme font`, which applies live.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/fonts.json") or "{}") or {}
local current = {}
local closeButton = true
local tab = "ui"
local hover = nil -- card under the pointer
local query = "" -- search filter
local iconState = {} -- the icons' state file as a map
local slots = {} -- the user's presets: { name, keys }, in saved order
local saved = nil -- the default snapshot, when there is one
local newName = "" -- name for the next saved preset

local samples = {
  sans = "Ação rápida: você já configurou o pen drive?",
  serif = "O tipo serifado conduz o olho pela linha.",
  mono = "if x != 0O1lI { return \"ok\" } // => <=",
  emoji = "😀 🫠 🪿 👍🏽 🇧🇷 ❤️ ✨",
}

local tabs = {
  { key = "presets", glyph = "layout-grid", tooltip = "Presets and every size" },
  { key = "ui", label = "UI", list = "ui", sample = samples.sans, title = "Interface", sizes = { { "ui", "Size" } } },
  { key = "term", label = "Term", list = "mono", sample = samples.mono, title = "Terminal", sizes = { { "term", "Size" } } },
  { key = "mono", label = "Code", list = "mono", sample = samples.mono, title = "Code in apps", sizes = { { "mono", "Apps" }, { "editor", "Emacs" } } },
  { key = "serif", label = "Serif", list = "serif", sample = samples.serif, title = "Serif" },
  { key = "emoji", label = "Emoji", list = "emoji", sample = samples.emoji, title = "Emoji" },
  { key = "icons", label = "Icons", title = "Icons" },
  { key = "apps", label = "Apps", title = "App icons" },
}
local families = { "ui", "serif", "mono", "term", "emoji" }

local render

-- the state file over the defaults ("key=value" lines)
local function refresh()
  current = {}
  for k, v in pairs(data.default or {}) do current[k] = v end
  local raw = noctalia.readFile(data.state .. "/font/state") or ""
  for k, v in raw:gmatch("([%w_]+)=([^\n]*)") do current[k] = v end
  iconState = {}
  for k, v in (noctalia.readFile(data.state .. "/icons") or ""):gmatch("([%w_.-]+)=([^\n]*)") do iconState[k] = v end
  slots = {}
  local byName = {}
  for name, k, v in (noctalia.readFile(data.state .. "/font/slots") or ""):gmatch("([^\t\n]+)\t([%w_.-]+)=([^\n]*)") do
    if not byName[name] then
      byName[name] = {}
      table.insert(slots, { name = name, keys = byName[name] })
    end
    byName[name][k] = v
  end
  saved = nil
  for k, v in (noctalia.readFile(data.state .. "/font/default") or ""):gmatch("([%w_.-]+)=([^\n]*)") do
    saved = saved or {}
    saved[k] = v
  end
end

local function same(a, b)
  if not a or not b then return false end
  for k, v in pairs(a) do
    if b[k] ~= v then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- a snapshot (`theme font save`/`default`) is in use when its fonts, sizes
-- and icons all are
local function snapshotOn(snap)
  if not snap then return false end
  local icons = 0
  for k, v in pairs(snap) do
    local name = k:match("^icons%.(.+)")
    if name then
      icons += 1
      if iconState[name] ~= v then return false end
    elseif current[k] ~= v then
      return false
    end
  end
  for _ in pairs(iconState) do icons -= 1 end
  return icons == 0
end

-- runs `theme font ARGS...` (argv, no shell) and redraws with the new state
local function font(...)
  noctalia.runAsync({ data.theme, "font", ... }, function(_result)
    refresh()
    render()
  end)
end

local function tabOf(key)
  for _, t in ipairs(tabs) do
    if t.key == key then return t end
  end
  return tabs[2]
end

-- emoji go through the generic "emoji" family whatever a label asks: their
-- previews are images drawn at build time (home/ui/noctalia.nix)
local function emojiImage(name, height)
  return ui.row({ justify = "start" }, {
    ui.image({ path = data.emojiPreviews .. "/" .. (name:gsub(" ", "-")) .. ".png", height = height, width = height * 10, fit = "contain" }),
    ui.spacer({ flexGrow = 1 }),
  })
end

local function caption(text, family)
  return ui.label({ text = text, fontSize = 11, color = "on_surface_variant", fontFamily = family, maxLines = 1 })
end

-- hover highlight shared by every card
local function hoverable(id)
  return function(state)
    hover = state == "true" and id or (hover ~= id and hover or nil)
    render()
  end
end

local function card(id, on, onClick, children, extra)
  local props = {
    key = id,
    flexGrow = 1,
    gap = 4,
    padding = 10,
    radius = 12,
    fill = on and "primary/0.15" or (hover == id and "surface_variant/0.6" or "surface_variant/0.2"),
    border = on and "primary" or (hover == id and "outline/0.6" or "outline/0.2"),
    borderWidth = on and 2 or 1,
    onClick = onClick,
    onHover = hoverable(id),
  }
  for k, v in pairs(extra or {}) do props[k] = v end
  return ui.column(props, children)
end

local function check(on)
  return ui.glyph({ name = "circle-check-filled", size = 14, color = "primary", visible = on })
end

-- segmented tabs, as the Light / Dark / Auto switch of the theme panel
local function tabBar()
  local buttons = {}
  for _, t in ipairs(tabs) do
    table.insert(buttons, ui.button({
      text = t.label,
      glyph = t.glyph,
      tooltip = t.tooltip,
      variant = tab == t.key and "primary" or "ghost",
      controlSize = "sm",
      flexGrow = t.label and 1 or 0,
      onClick = function()
        tab = t.key
        query = ""
        render()
      end,
    }))
  end
  return ui.row({ gap = 2, padding = 4, radius = 12, fill = "surface_variant/0.5" }, buttons)
end

-- [−] value [+], the value in a fixed box so rows line up
local function stepper(label, key)
  return ui.row({ gap = 2, align = "center" }, {
    caption(label),
    ui.button({ glyph = "minus", variant = "ghost", controlSize = "sm", onClick = function() font("size", key, "-1") end }),
    ui.row({ width = 34, justify = "center" }, {
      ui.label({ text = current[key .. "_size"] or "", fontSize = 13, fontWeight = "bold" }),
    }),
    ui.button({ glyph = "plus", variant = "ghost", controlSize = "sm", onClick = function() font("size", key, "+1") end }),
  })
end

-- the role's font in use, large, with its sizes
local function preview(t)
  local family = current[t.key]
  local size = tonumber(current[(t.sizes and t.sizes[1][1] or "ui") .. "_size"]) or 12
  local controls = {}
  for _, s in ipairs(t.sizes or {}) do table.insert(controls, stepper(s[2], s[1])) end
  return ui.column({ gap = 8, padding = 14, radius = 12, fill = "primary/0.08", border = "primary/0.4", borderWidth = 1 }, {
    ui.row({ gap = 6, align = "center" }, {
      ui.label({ text = t.title, fontSize = 11, color = "primary", fontWeight = "medium", flexGrow = 1 }),
      ui.label({ text = family, fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.label({ text = family, fontSize = 22, fontFamily = family, maxLines = 1 }),
    t.key == "emoji" and emojiImage(family, 30)
      or ui.label({ text = t.sample, fontSize = math.max(size * 1.15, 12), fontFamily = family, maxLines = 2 }),
    ui.row({ gap = 12, align = "center", visible = #controls > 0 }, controls),
  })
end

-- every family of the role, each written in itself
local function familyCards(t)
  local q = query:lower()
  local cards = {}
  for _, name in ipairs(data.roles[t.list] or {}) do
    if q == "" or name:lower():find(q, 1, true) then
      local on = name == current[t.key]
      table.insert(cards, card("family-" .. t.key .. name, on, function() font(t.key, name) end, {
        ui.row({ gap = 6, align = "center" }, {
          ui.label({ text = name, fontSize = 15, fontFamily = name, fontWeight = on and "bold" or "normal", color = on and "primary" or "on_surface", flexGrow = 1, maxLines = 1 }),
          check(on),
        }),
        t.key == "emoji" and emojiImage(name, 20) or caption(t.sample, name),
      }))
    end
  end
  if #cards == 0 then
    table.insert(cards, ui.label({ text = "No fonts found", color = "on_surface_variant", textAlign = "center" }))
  end
  return cards
end

-- a preset is active when every family it sets is the one in use
local function presetOn(p)
  for _, k in ipairs(families) do
    if p[k] and p[k] ~= current[k] then return false end
  end
  return true
end

local function presetCards()
  local list = {}
  for _, p in ipairs(data.presets or {}) do
    if p.name == "default" then table.insert(list, 1, p) else table.insert(list, p) end
  end
  local rows = {}
  local function one(p)
    local on = presetOn(p)
    return card("preset-" .. p.name, on, function() font("preset", p.name) end, {
      ui.row({ gap = 6, align = "center" }, {
        ui.label({ text = p.name:sub(1, 1):upper() .. p.name:sub(2), fontSize = 16, fontFamily = p.ui, fontWeight = "bold", color = on and "primary" or "on_surface", flexGrow = 1 }),
        check(on),
      }),
      caption(p.ui, p.ui),
      caption(p.term, p.term),
    })
  end
  for i = 1, #list, 2 do
    table.insert(rows, ui.row({ gap = 8 }, { one(list[i]), list[i + 1] and one(list[i + 1]) or ui.spacer({ flexGrow = 1 }) }))
  end
  table.insert(rows, ui.label({ text = "Yours", fontSize = 13, fontWeight = "medium" }))
  table.insert(rows, caption("Fonts, sizes and icons as they are now, under a name"))
  table.insert(rows, ui.row({ gap = 6, align = "center" }, {
    ui.input({
      key = "slot-name",
      placeholder = "Name…",
      controlSize = "sm",
      flexGrow = 1,
      onChange = function(value) newName = value end,
    }),
    ui.button({
      text = "Save",
      glyph = "device-floppy",
      variant = "primary",
      controlSize = "sm",
      onClick = function()
        if newName:match("%S") then font("save", (newName:gsub("^%s+", ""):gsub("%s+$", ""))) end
      end,
    }),
  }))
  for _, slot in ipairs(slots) do
    local on = snapshotOn(slot.keys)
    local k = slot.keys
    local pack = k["icons.pack"] or "nerd"
    table.insert(rows, card("slot-" .. slot.name, on, function() font("preset", slot.name) end, {
      ui.row({ gap = 6, align = "center" }, {
        ui.label({ text = slot.name, fontSize = 15, fontFamily = k.ui, fontWeight = "bold", color = on and "primary" or "on_surface", flexGrow = 1, maxLines = 1 }),
        ui.label({ text = "default", fontSize = 10, color = "primary", visible = same(k, saved) }),
        check(on),
        ui.button({ glyph = "trash", variant = "ghost", controlSize = "sm", tooltip = "Delete", onClick = function() font("delete", slot.name) end }),
      }),
      caption((k.ui or "") .. " " .. (k.ui_size or "") .. " · " .. (k.term or "") .. " " .. (k.term_size or "") .. " · icons: " .. pack, k.ui),
    }))
  end
  table.insert(rows, ui.row({ gap = 6, align = "center", padding = 6 }, {
    ui.label({ text = "Every size", fontSize = 12, color = "on_surface_variant", flexGrow = 1 }),
    ui.button({ text = "Smaller", glyph = "minus", variant = "outline", controlSize = "sm", onClick = function() font("size", "-1") end }),
    ui.button({ text = "Larger", glyph = "plus", variant = "outline", controlSize = "sm", onClick = function() font("size", "+1") end }),
  }))
  return rows
end

-- icons of the bar (`theme icons`, home/theme/icons): the index (every pack's
-- icons by name, the bar's glyphs) is read when the tab first opens
local icons = { index = nil, pack = "", own = {}, editing = nil, query = "" }

-- glyphs a pack card shows besides the tags
local sampleBar = { "bluetooth", "memory", "cpu-usage", "storage", "volume-high", "wifi", "palette", "keyboard", "clipboard", "bell" }

local function iconsRefresh()
  if not icons.index then
    icons.index = noctalia.json.decode(noctalia.readFile(data.iconIndex) or "{}") or {}
    icons.bar = {}
    for _, b in ipairs(icons.index.bar or {}) do icons.bar[b.name] = b end
  end
  icons.pack, icons.own = "", {}
  local raw = noctalia.readFile(data.state .. "/icons") or ""
  for k, v in raw:gmatch("([%w_.-]+)=([^\n]*)") do
    if k == "pack" then icons.pack = v else icons.own[k] = v end
  end
  if not icons.index.packs[icons.pack] then icons.pack = "nerd" end
end

local function iconTheme(...)
  noctalia.runAsync({ data.theme, "icons", ... }, function(_result)
    refresh()
    iconsRefresh()
    render()
  end)
end

-- an icon of PACK, or Tabler's when the pack has none: { name, char, family, weight }
local function iconOf(pack, kind, key)
  local p = icons.index.packs[pack]
  if kind == "tag" then
    local name = icons.own[pack .. "." .. key] or p.tags[key]
    return { name = name, char = utf8.char(p.glyphs[name] or 0x3F), family = p.family, weight = p.weight }
  end
  local name = icons.own[pack .. ".bar." .. key] or p.bar[key]
  if name and p.glyphs[name] then
    return { name = name, char = utf8.char(p.glyphs[name]), family = p.family, weight = p.weight }
  end
  local t = icons.index.packs.tabler
  return { name = nil, char = utf8.char(icons.bar[key].tabler), family = t.family, weight = t.weight }
end

local function glyph(icon, size, color)
  return ui.label({ text = icon.char, fontSize = size, fontFamily = icon.family, fontWeight = icon.weight >= 800 and "heavy" or "normal", color = color })
end

local function packCard(pack)
  local p = icons.index.packs[pack]
  local on = pack == icons.pack
  local color = on and "primary" or "on_surface"
  local tags, bar = {}, {}
  for t = 1, 10 do table.insert(tags, glyph(iconOf(pack, "tag", tostring(t)), 14, color)) end
  for _, b in ipairs(sampleBar) do table.insert(bar, glyph(iconOf(pack, "bar", b), 14, "on_surface_variant")) end
  return card("pack-" .. pack, on, function() iconTheme("pack", pack) end, {
    ui.row({ gap = 6, align = "center" }, {
      ui.label({ text = p.title, fontSize = 13, fontWeight = on and "bold" or "medium", color = color, flexGrow = 1 }),
      check(on),
    }),
    ui.row({ gap = 5, align = "center" }, tags),
    ui.row({ gap = 5, align = "center" }, bar),
  })
end

-- every icon of the pack whose name has the query (the first 48)
local function iconGrid(kind, key)
  local p = icons.index.packs[icons.pack]
  local q = icons.query:lower()
  local names = {}
  for name in pairs(p.glyphs) do
    if q == "" or name:lower():find(q, 1, true) then table.insert(names, name) end
  end
  table.sort(names)
  local rows, row = {}, {}
  for i = 1, math.min(#names, 48) do
    local name = names[i]
    local id = "icon-" .. name
    table.insert(row, ui.column({
      key = id,
      width = 40,
      height = 40,
      align = "center",
      justify = "center",
      radius = 8,
      fill = hover == id and "primary/0.2" or "surface/0.4",
      tooltip = name,
      onHover = hoverable(id),
      onClick = function()
        icons.editing = nil
        iconTheme(kind, key, name)
      end,
    }, { glyph({ char = utf8.char(p.glyphs[name]), family = p.family, weight = p.weight }, 20, "on_surface") }))
    if #row == 8 then
      table.insert(rows, ui.row({ gap = 2 }, row))
      row = {}
    end
  end
  if #row > 0 then table.insert(rows, ui.row({ gap = 2 }, row)) end
  if #names == 0 then table.insert(rows, caption("No icon has that in its name")) end
  if #names > 48 then table.insert(rows, caption(#names .. " icons: type more to narrow them")) end
  return rows
end

-- a tag or a bar glyph: its icon, and Change opening the search
local function iconRow(kind, key, title)
  local icon = iconOf(icons.pack, kind, key)
  local id = kind .. ":" .. key
  local editing = icons.editing == id
  local own = icons.own[icons.pack .. (kind == "tag" and "." or ".bar.") .. key] ~= nil
  local children = {
    ui.row({ gap = 10, align = "center" }, {
      ui.row({ width = 26, justify = "center" }, { glyph(icon, 20, "primary") }),
      ui.column({ gap = 0, flexGrow = 1 }, {
        ui.label({ text = title, fontSize = 12, maxLines = 1 }),
        caption(icon.name or "Tabler's (none in this pack)"),
      }),
      ui.button({
        glyph = "restore",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "The pack's icon",
        visible = own,
        onClick = function() iconTheme("reset", key) end,
      }),
      ui.button({
        text = editing and "Close" or "Change",
        variant = editing and "primary" or "ghost",
        controlSize = "sm",
        onClick = function()
          icons.editing = not editing and id or nil
          icons.query = ""
          render()
        end,
      }),
    }),
  }
  if editing then
    table.insert(children, ui.input({
      key = "icon-search-" .. id,
      placeholder = "Search icons…",
      controlSize = "sm",
      onChange = function(value)
        icons.query = value
        render()
      end,
    }))
    for _, r in ipairs(iconGrid(kind, key)) do table.insert(children, r) end
  end
  return ui.column({ gap = 6, padding = 8, radius = 10, fill = editing and "surface_variant/0.4" or "surface_variant/0.15" }, children)
end

local function iconsBody()
  iconsRefresh()
  local packs = {}
  for name in pairs(icons.index.packs) do table.insert(packs, name) end
  table.sort(packs)
  local list = {}
  for i = 1, #packs, 2 do
    table.insert(list, ui.row({ gap = 8 }, { packCard(packs[i]), packs[i + 1] and packCard(packs[i + 1]) or ui.spacer({ flexGrow = 1 }) }))
  end
  table.insert(list, ui.label({ text = "Tags", fontSize = 13, fontWeight = "medium" }))
  for t = 1, 10 do table.insert(list, iconRow("tag", tostring(t), "Tag " .. t)) end
  table.insert(list, ui.label({ text = "Bar", fontSize = 13, fontWeight = "medium" }))
  for _, b in ipairs(icons.index.bar) do table.insert(list, iconRow("bar", b.name, b.title)) end
  return { ui.scroll({ flexGrow = 1, gap = 8 }, list) }
end

-- app icon themes (`theme icons apps`): a few of each theme's icons, drawn
-- from its files at build time (home/ui/noctalia.nix)
local function appsBody()
  iconsRefresh()
  icons.previews = icons.previews or noctalia.json.decode(noctalia.readFile(data.appPreviews) or "{}") or {}
  local currentApps = icons.own.apps or data.appsDefault
  local tint = icons.own.tint == "on"
  local list = {
    ui.row({ gap = 8, align = "center", padding = 6 }, {
      ui.column({ gap = 0, flexGrow = 1 }, {
        ui.label({ text = "Tint app icons", fontSize = 13 }),
        caption("Bar, tray and launcher icons in the theme's color"),
      }),
      ui.toggle({ checked = tint, onChange = function(value) iconTheme("tint", value == "true" and "on" or "off") end }),
    }),
  }
  local function one(a)
    local on = a.name == currentApps
    local row = {}
    for _, path in ipairs(icons.previews[a.name] or {}) do table.insert(row, ui.image({ path = path, width = 28, height = 28, fit = "contain" })) end
    return card("apps-" .. a.name, on, function() iconTheme("apps", a.name) end, {
      ui.row({ gap = 6, align = "center" }, {
        ui.label({ text = a.title, fontSize = 13, fontWeight = on and "bold" or "medium", color = on and "primary" or "on_surface", flexGrow = 1 }),
        check(on),
      }),
      ui.row({ gap = 6, align = "center" }, row),
    })
  end
  for i = 1, #data.apps, 2 do
    table.insert(list, ui.row({ gap = 8 }, { one(data.apps[i]), data.apps[i + 1] and one(data.apps[i + 1]) or ui.spacer({ flexGrow = 1 }) }))
  end
  return { ui.scroll({ flexGrow = 1, gap = 8 }, list) }
end

render = function()
  local header = {
    ui.glyph({ name = "typography", size = 18, color = "primary" }),
    ui.column({ gap = 0, flexGrow = 1 }, {
      ui.label({ text = "Fonts", fontSize = 16, fontWeight = "bold" }),
      ui.label({ text = (current.ui or "") .. " · " .. (current.term or "") .. (snapshotOn(saved) and " · default" or ""), fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.button({
      glyph = snapshotOn(saved) and "pinned" or "pin",
      variant = "ghost",
      controlSize = "sm",
      tooltip = snapshotOn(saved) and "This is the default" or "Make fonts, sizes and icons as they are now the default",
      onClick = function() font("default") end,
    }),
    ui.button({ glyph = "restore", variant = "ghost", controlSize = "sm", tooltip = "Back to the default", onClick = function() font("reset") end }),
  }
  if closeButton then
    table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }))
  end

  local t = tabOf(tab)
  local body
  if tab == "presets" then
    body = { ui.scroll({ flexGrow = 1, gap = 8 }, presetCards()) }
  elseif tab == "icons" then
    body = iconsBody()
  elseif tab == "apps" then
    body = appsBody()
  else
    body = {
      preview(t),
      ui.input({
        key = "search-" .. tab,
        placeholder = "Search " .. t.title:lower() .. " fonts…",
        controlSize = "sm",
        onChange = function(value)
          query = value
          render()
        end,
      }),
      ui.scroll({ flexGrow = 1, gap = 8, revealKey = "family-" .. t.key .. (current[t.key] or "") }, familyCards(t)),
    }
  end

  local children = { ui.row({ align = "center", gap = 10 }, header), tabBar() }
  for _, b in ipairs(body) do table.insert(children, b) end
  table.insert(children, caption("Everything switches live; LibreWolf takes it when started again."))
  panel.render(ui.column({ flexGrow = 1, gap = 12 }, children))
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  refresh()
  render()
  -- follow changes made elsewhere (terminal)
  panel.setWantsSecondTicks(true)
end

function update()
  local function now() return noctalia.json.encode({ current, iconState, slots, saved }) end
  local before = now()
  refresh()
  if before ~= now() then render() end
end
