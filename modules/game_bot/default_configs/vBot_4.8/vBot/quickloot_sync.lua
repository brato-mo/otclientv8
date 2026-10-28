setDefaultTab("Tools")

-- Server Quick Loot (Gunzodus and other servers with !quickloot commands for
-- old clients): sends the TargetBot loot list to the server one item at a
-- time as "!quickloot add,name", slow enough not to count as spam.

local panelName = "quickLootSync"
if type(storage[panelName]) ~= "table" then
  storage[panelName] = { delay = 2500, monster = "" }
end
local config = storage[panelName]

-- coins have no market name in the item data
local coinNames = { [3031] = "gold coin", [3035] = "platinum coin", [3043] = "crystal coin" }

local function itemName(id)
  if coinNames[id] then return coinNames[id] end
  local ok, data = pcall(function() return Item.create(id):getMarketData() end)
  if ok and data and data.name and data.name:len() > 0 then
    return data.name:lower()
  end
end

UI.Label("Server Quick Loot")

local ui = setupUI([[
Panel
  height: 19

  Button
    id: send
    anchors.top: parent.top
    anchors.left: parent.left
    width: 105
    height: 17
    text: Send loot list
    tooltip: Sends every item from the TargetBot loot list to the server as !quickloot add,name

  Button
    id: show
    anchors.top: parent.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Show list
    tooltip: !quickloot list
]])

local running = 0 -- bumped on every start/stop so old schedules stop
local function stop(text)
  running = running + 1
  ui.send:setText("Send loot list")
  if text then
    modules.game_textmessage.displayGameMessage("[Quick Loot] " .. text)
  end
end

local function start()
  local names, seen, skipped = {}, {}, 0
  for _, entry in ipairs(vBot.lootItems or {}) do
    local name = itemName(entry)
    if not name then
      skipped = skipped + 1
    elseif not seen[name] then
      seen[name] = true
      table.insert(names, name)
    end
  end
  if #names == 0 then
    return stop("TargetBot loot list is empty.")
  end

  running = running + 1
  local token = running
  local index = 0
  local function nextItem()
    if token ~= running or not g_game.isOnline() then return end
    index = index + 1
    if index > #names then
      local note = skipped > 0 and (" " .. skipped .. " item(s) have no name and were skipped.") or ""
      return stop("Sent " .. #names .. " item(s)." .. note)
    end
    ui.send:setText("Stop (" .. index .. "/" .. #names .. ")")
    say("!quickloot add," .. names[index])
    schedule(math.max(1000, tonumber(config.delay) or 2500), nextItem)
  end
  nextItem()
end

ui.send.onClick = function()
  if ui.send:getText() ~= "Send loot list" then
    return stop("Stopped.")
  end
  start()
end

ui.show.onClick = function()
  say("!quickloot list")
end

local monsterUi = setupUI([[
Panel
  height: 19

  BotTextEdit
    id: monster
    anchors.top: parent.top
    anchors.left: parent.left
    width: 105
    height: 17
    tooltip: Monster name, e.g. dragon

  Button
    id: pick
    anchors.top: parent.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Pick from monster
    tooltip: !quickloot monsterName (server shows that monster's loot to choose from)
]])

monsterUi.monster:setText(config.monster or "")
monsterUi.monster.onTextChange = function(widget, text)
  config.monster = text
end
monsterUi.pick.onClick = function()
  local monster = (config.monster or ""):trim()
  if monster:len() > 0 then
    say("!quickloot " .. monster)
  end
end

UI.Separator()
