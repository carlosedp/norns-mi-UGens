-- mi-ugens install
--
-- installs mi-UGens (Mutable
-- Instruments SuperCollider
-- plugins) built for norns
--
-- K3 download + install latest
-- K2 install local tarball
--    (dust/mi-UGens-norns*.tar.gz)
--
-- then SYSTEM > RESTART

local REPO = "carlosedp/norns-mi-UGens"
local URL = "https://github.com/" .. REPO .. "/releases/latest/download/mi-UGens-norns.tar.gz"
local EXT = "/home/we/.local/share/SuperCollider/Extensions"
local LOCAL_GLOB = "/home/we/dust/mi-UGens-norns*.tar.gz"

local busy = false
local status = {}   -- lines shown on screen

local function set_status(...)
  status = { ... }
  redraw()
end

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Short description of what's installed now, from the build's BUILDINFO file.
local function current_install()
  local f = io.open(EXT .. "/mi-UGens/BUILDINFO", "r")
  if not f then return "none (or an older build)" end
  local info = f:read("*a")
  f:close()
  local commit = info:match("commit:%s*(%x%x%x%x%x%x%x)") or "?"
  local built = info:match("built:%s*(%d%d%d%d%-%d%d%-%d%d)") or "?"
  return commit .. " " .. built
end

local function newest_local()
  return trim(util.os_capture("ls -t " .. LOCAL_GLOB .. " 2>/dev/null | head -1"))
end

-- Unpack the tarball (local path, or downloaded when url is given) to a temp
-- dir and run the install.sh that ships inside it.
local function install(src, url)
  busy = true
  local fetch = url
    and ("wget -q -T 180 -O \"$d/b.tgz\" '" .. url .. "' || { echo 'download failed'; exit 1; }")
    or ("cp '" .. src .. "' \"$d/b.tgz\"")
  local cmd = "bash -c '" .. ([[
    d=$(mktemp -d); trap "rm -rf $d" EXIT
    FETCH
    tar -C "$d" -xzf "$d/b.tgz" || { echo "bad tarball"; exit 1; }
    bash "$d/install.sh" "$d/mi-UGens"
  ]]):gsub("FETCH", function() return fetch end):gsub("'", "'\\''") .. "' 2>&1; echo \"exit=$?\""

  norns.system_cmd(cmd, function(out)
    busy = false
    print(out)
    local ok = out:match("exit=0") ~= nil
    local installed = out:match("installed: ([^\n]*)")
    local n = 0
    for _ in (installed or ""):gmatch("%S+") do n = n + 1 end
    if ok then
      local warn = out:match("WARNING") and "check maiden: duplicates in dust!" or ""
      set_status("installed " .. n .. " UGens", warn, "", "SYSTEM > RESTART to load")
    else
      local err = trim(out:gsub("exit=%d+", "")):match("[^\n]*$")
      set_status("install failed:", err, "", "see maiden for details")
    end
  end)
end

function init()
  set_status("installed: " .. current_install(), "", "K3: download latest", "K2: install from dust/")
end

function key(n, z)
  if z == 0 or busy then return end
  if n == 3 then
    set_status("downloading latest...", REPO)
    install(nil, URL)
  elseif n == 2 then
    local f = newest_local()
    if f == "" then
      set_status("no local tarball", "copy mi-UGens-norns*.tar.gz", "into dust/ first")
    else
      set_status("installing", f:match("[^/]+$"))
      install(f)
    end
  end
end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.font_size(8)
  screen.level(15)
  screen.move(0, 8)
  screen.text("MI-UGENS INSTALL")
  screen.level(busy and 4 or 10)
  for i, line in ipairs(status) do
    screen.move(0, 18 + i * 9)
    screen.text(line)
  end
  screen.update()
end
