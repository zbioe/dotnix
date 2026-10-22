--!nonstrict
-- Proton Pass's lock code: handed to `pw unlock` through a file in RAM it removes at once.

local data = noctalia.json.decode(noctalia.readFile(noctalia.pluginDir() .. "/pass.json") or "{}") or {}
local dir = (noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/pw"
local code = ""
local busy = false
local failed = false
local attempt = 0 -- a new key empties the field after a wrong code

local render

local function submit()
  if busy or code == "" then
    return
  end
  busy = true
  failed = false
  render()
  local file = dir .. "/unlock-" .. tostring(os.time())
  noctalia.writeFile(file, code)
  code = ""
  noctalia.runAsync({ data.command, "unlock", "--file", file }, function(result)
    busy = false
    noctalia.removeFile(file)
    if result.exitCode == 0 then
      noctalia.state.set("unlocked", os.time())
      panel.close()
      -- back to the search it came from
      local query = noctalia.readFile(dir .. "/query") or ""
      noctalia.runAsync({ "noctalia", "msg", "panel-open", "launcher", "/pw " .. query })
    else
      failed = true
      attempt += 1
      render()
    end
  end, 30000)
end

render = function()
  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 10 }, {
      ui.glyph({ name = "lock", size = 18, color = "primary" }),
      ui.label({ text = "Proton Pass is locked", fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
    }),
    ui.input({
      key = "code-" .. attempt,
      password = true,
      focus = true,
      placeholder = "Lock code",
      enabled = not busy,
      onChange = function(value)
        code = value
      end,
      onSubmit = function()
        submit()
      end,
    }),
    ui.label({
      text = failed and "Wrong lock code" or "It locks again with the screen",
      fontSize = 10,
      color = failed and "error" or "on_surface_variant",
    }),
    ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = "", flexGrow = 1 }),
      ui.button({
        text = "Cancel",
        variant = "ghost",
        onClick = function()
          panel.close()
        end,
      }),
      ui.button({
        text = busy and "Unlocking…" or "Unlock",
        glyph = "lock-open",
        enabled = not busy,
        onClick = function()
          submit()
        end,
      }),
    }),
  }))
end

function onOpen(_context)
  code = ""
  failed = false
  render()
end
