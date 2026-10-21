--!nonstrict
-- /pw: Proton Pass items. Enter copies the password, the row below the
-- one-time code; with a few matches left, username, e-mail and website too.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/pass.json") or "{}") or {}
local dir = (noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/pw"
local items = nil
local state = nil
local loading = false
local failed = false
local lastText = ""

local glyphs = { login = "key", note = "note" }

-- the lock code panel says so at once (and the list is read again)
noctalia.state.watch("unlocked", function(_value)
  state = "unlocked"
  local raw = noctalia.readFile(dir .. "/index.json")
  items = raw and noctalia.json.decode(raw) or nil
end)

local function readIndex()
  local raw = noctalia.readFile(dir .. "/index.json")
  items = raw and noctalia.json.decode(raw) or nil
end

local publish

-- the session state, and the index once unlocked (built in the background)
local function refresh()
  if loading then return end
  loading = true
  noctalia.runAsync({ data.command, "state" }, function(result)
    state = (result.stdout or ""):match("%S+")
    readIndex()
    if state == "unlocked" and items == nil then
      -- about 10 s; runAsync stops a command after 5 s unless told otherwise
      noctalia.runAsync({ data.command, "index" }, function(_r)
        loading = false
        readIndex()
        failed = items == nil
        publish(lastText)
      end, 60000)
    else
      loading = false
      publish(lastText)
    end
  end, 30000)
end

local function action(id, title, subtitle, glyph, score)
  return { id = id, title = title, subtitle = subtitle, glyph = glyph, score = score }
end

publish = function(text)
  if state == "logged-out" then
    launcher.setResults(text, { action("none", "Proton Pass: not logged in", "run `pass-cli login` in a terminal", "key-off") })
    return
  end
  if state == "locked" then
    launcher.setResults(text, { action("unlock", "Proton Pass is locked", "Enter: type the lock code", "lock") })
    return
  end
  if items == nil and failed then
    launcher.setResults(text, { action("retry", "Couldn't read Proton Pass", "Enter: try again", "alert-triangle") })
    return
  end
  if items == nil then
    launcher.setResults(text, { action("none", "Reading Proton Pass… (about 10 s the first time)", nil, "loader-2") })
    return
  end

  local matches = {}
  for _, item in ipairs(items) do
    if glyphs[item.type] then
      local score = text == "" and 0 or noctalia.fuzzyScore(text, item.title)
      if score then table.insert(matches, { item = item, score = score }) end
    end
  end
  table.sort(matches, function(a, b) return a.score > b.score end)

  local results = {}
  for i, m in ipairs(matches) do
    if i > 40 then break end
    local item = m.item
    local base = 1000 - i * 10
    local where = (item.user ~= nil and item.user ~= "") and (item.user .. " · " .. item.vault) or item.vault
    if item.type == "note" then
      table.insert(results, action("copy\t" .. item.uri .. "\tnote", item.title, "copy the note · " .. item.vault, "note", base))
    else
      table.insert(results, action("copy\t" .. item.uri .. "\tpassword", item.title, "password · " .. where, "key", base))
      if item.totp then
        table.insert(results, action("totp\t" .. item.uri, "    one-time code", item.title, "clock", base - 1))
      end
      if #matches <= 3 then
        table.insert(results, action("copy\t" .. item.uri .. "\tusername", "    username", item.title, "user", base - 2))
        table.insert(results, action("copy\t" .. item.uri .. "\temail", "    e-mail", item.title, "mail", base - 3))
        table.insert(results, action("open\t" .. item.uri, "    open the website", item.title, "external-link", base - 4))
      end
    end
  end
  if #results == 0 then
    table.insert(results, action("none", "Nothing found", "the list refreshes when Pass unlocks", "search"))
  end
  launcher.setResults(text, results)
end

function onQuery(text)
  lastText = text
  -- where the lock code panel brings the launcher back to
  noctalia.writeFile(dir .. "/query", text)
  publish(text)
  if text == "" or state ~= "unlocked" or items == nil then refresh() end
end

function onActivate(id)
  if id == "unlock" then
    noctalia.togglePanel("dotnix/pass:unlock")
    return
  end
  if id == "retry" then
    failed = false
    launcher.setQuery("/pw " .. lastText)
    refresh()
    return
  end
  local verb, uri, field = id:match("^(%a+)\t([^\t]+)\t?(.*)$")
  if not verb then return end
  local argv = { data.command, verb, uri }
  if field and field ~= "" then table.insert(argv, field) end
  noctalia.runAsync(argv, function(result)
    if result.exitCode ~= 0 then
      -- locked by its own idle timeout since the list was read
      noctalia.runAsync({ data.command, "state" }, function(r)
        if (r.stdout or ""):match("locked") then noctalia.togglePanel("dotnix/pass:unlock") end
      end, 30000)
    end
  end, 30000)
end
