require("hs.ipc")
local spaces = require("hs.spaces")

-- Per-Space wallpaper tint: color the desktop by which Space you're on, so a
-- glance at any exposed background tells you where you are. macOS Tahoe no
-- longer persists native per-Space wallpapers, so we set them dynamically on
-- every Space change instead. Colors are keyed by Space position (1-4) per
-- screen; images live in hammerspoon/wallpapers (symlinked into ~/.hammerspoon).
local wallpaperDir = hs.configdir .. "/wallpapers/"
local spaceWallpapers = {
  wallpaperDir .. "space1-dusty-red.png",   -- Space 1
  wallpaperDir .. "space2-sage-green.png",  -- Space 2
  wallpaperDir .. "space3-slate-blue.png",  -- Space 3
  wallpaperDir .. "space4-ochre.png",       -- Space 4
}

local function applySpaceWallpapers()
  local active = spaces.activeSpaces() -- { screenUUID = spaceID }
  if not active then return end
  for _, screen in ipairs(hs.screen.allScreens()) do
    local uuid = screen:getUUID()
    local screenSpaces = spaces.spacesForScreen(uuid)
    local current = active[uuid]
    if screenSpaces and current then
      local idx = hs.fnutils.indexOf(screenSpaces, current)
      local img = idx and spaceWallpapers[idx]
      if img then screen:desktopImageURL("file://" .. img) end
    end
  end
end

-- Global so the watcher isn't garbage-collected.
spaceWallpaperWatcher = spaces.watcher.new(applySpaceWallpapers)
spaceWallpaperWatcher:start()
applySpaceWallpapers() -- paint the current Space on load

-- Focus an already-running app, preferring a window on the current space.
local function focusApp(app)
  local currentSpace = spaces.focusedSpace()
  for _, win in ipairs(app:allWindows()) do
    local winSpaces = spaces.windowSpaces(win:id())
    if winSpaces then
      for _, space in ipairs(winSpaces) do
        if space == currentSpace then
          win:focus()
          return
        end
      end
    end
  end

  app:activate()
end

local function activateOrOpen(bundleID)
  local app = hs.application.get(bundleID)
  if not app then
    hs.application.launchOrFocusByBundleID(bundleID)
    return
  end
  focusApp(app)
end

-- Cycle focus through the open apps in `bundleIDs` (list order).
-- Only already-running apps participate; nothing is launched.
-- If a group app is frontmost, advance to the next open one (wrapping);
-- otherwise focus the first open one.
local function cycleApps(bundleIDs)
  local running = {}
  for _, id in ipairs(bundleIDs) do
    local app = hs.application.get(id)
    if app then table.insert(running, app) end
  end
  if #running == 0 then return end

  local front = hs.application.frontmostApplication()
  local frontBundle = front and front:bundleID()
  local frontIdx = nil
  for i, app in ipairs(running) do
    if app:bundleID() == frontBundle then
      frontIdx = i
      break
    end
  end

  local target
  if frontIdx then
    target = running[(frontIdx % #running) + 1]
  else
    target = running[1]
  end
  focusApp(target)
end

hs.hotkey.bind({"ctrl"}, "1", function()
  activateOrOpen("com.google.Chrome")
end)

hs.hotkey.bind({"ctrl"}, "2", function()
  activateOrOpen("com.microsoft.VSCode")
end)

hs.hotkey.bind({"ctrl"}, "3", function()
  activateOrOpen("com.mitchellh.ghostty")
end)

hs.hotkey.bind({"ctrl"}, "4", function()
  cycleApps({
    "notion.id",        -- Notion
    "com.apple.Notes",  -- Notes
    "com.linear",       -- Linear
  })
end)

hs.hotkey.bind({"ctrl"}, "5", function()
  cycleApps({
    "com.hnc.Discord",            -- Discord
    "net.whatsapp.WhatsApp",      -- WhatsApp
    "ru.keepcoder.Telegram",      -- Telegram
    "com.tinyspeck.slackmacgap",  -- Slack
  })
end)

-- Window grid (Tactile-style)
-- Columns: 2/5 | 2/5 | 1/5   Rows: 1/3 | 1/3 | 1/3
local gap = 8
local colStarts  = {0, 2/5, 4/5}
local colWidths  = {2/5, 2/5, 1/5}
local rowStarts  = {0, 1/3, 2/3}
local rowHeights = {1/3, 1/3, 1/3}

local gridCells = {
  q = {col=1, row=1}, w = {col=2, row=1}, e = {col=3, row=1},
  a = {col=1, row=2}, s = {col=2, row=2}, d = {col=3, row=2},
  z = {col=1, row=3}, x = {col=2, row=3}, c = {col=3, row=3},
}

local gridModal = hs.hotkey.modal.new({"ctrl"}, "g")
local selected = {}
local originalFrame = nil

function gridModal:entered()
  selected = {}
  local win = hs.window.focusedWindow()
  if win then originalFrame = win:frame() end
  hs.alert.show("Grid: q w e / a s d / z x c — Esc to cancel", 2)
end

function gridModal:exited()
  selected = {}
  originalFrame = nil
end

local function applySelection()
  if #selected == 0 then return end
  local minCol, maxCol = 4, 0
  local minRow, maxRow = 3, 0
  for _, cell in ipairs(selected) do
    minCol = math.min(minCol, cell.col)
    maxCol = math.max(maxCol, cell.col)
    minRow = math.min(minRow, cell.row)
    maxRow = math.max(maxRow, cell.row)
  end
  local win = hs.window.focusedWindow()
  if not win then return end
  local screen = win:screen():frame()
  local sw, sh = screen.w, screen.h
  local x = colStarts[minCol] * sw + screen.x
  local y = rowStarts[minRow] * sh + screen.y
  local w = 0
  for c = minCol, maxCol do w = w + colWidths[c] end
  local h = 0
  for r = minRow, maxRow do h = h + rowHeights[r] end
  local halfGap = gap / 2
  local gapLeft   = minCol > 1 and halfGap or 0
  local gapRight  = maxCol < #colStarts and halfGap or 0
  local gapTop    = minRow > 1 and halfGap or 0
  local gapBottom = maxRow < #rowStarts and halfGap or 0
  win:setFrame({
    x = x + gapLeft,
    y = y + gapTop,
    w = w * sw - gapLeft - gapRight,
    h = h * sh - gapTop - gapBottom,
  })
end

for key, cell in pairs(gridCells) do
  gridModal:bind({}, key, function()
    table.insert(selected, cell)
    applySelection()
  end)
end

gridModal:bind({}, "escape", function()
  if originalFrame then
    local win = hs.window.focusedWindow()
    if win then win:setFrame(originalFrame) end
  end
  gridModal:exit()
end)

gridModal:bind({}, "return", function()
  gridModal:exit()
end)
