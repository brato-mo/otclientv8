setDefaultTab("Main")

-- Druid Attack: one switch that attacks with (elder) druid spells and runes.
-- Works as a file in vBot or pasted alone into an empty script tab.
-- Attacks only while you have a target (TargetBot or your own click).
--
-- What it uses, first match wins (one attack per attack cooldown):
--  1. Big area spell (exevo gran mas frigo / tera) when enough monsters are
--     around you.
--  2. Wave (exevo gran frigo hur, exevo tera hur, exevo frigo hur) when enough
--     monsters are in one direction. It turns you to the best side first.
--  3. Area rune (avalanche, stone shower, ...) on the tile that hits the most
--     monsters.
--  4. Single target: ultimate strike, strong strike, rune (sudden death),
--     normal strike. Each one only while the target HP % is above its number,
--     so you don't waste a big spell on an almost dead monster.
-- Safe mode: no area spells, waves or area runes while another player (not in
-- your party) is on screen, so you don't hit people or get a skull.
-- Spells need mana above "Attack spells only above MP %" so the healer always
-- has mana; runes are still used when mana is low.
--
-- Rune ids are client ids (the same on every server version):
-- 3155 sudden death, 3158 icicle, 3161 avalanche, 3175 stone shower,
-- 3191 great fireball, 3202 thunderstorm.

g_ui.loadUIFromString([[
DruidAttackRow < Panel
  height: 20
  margin-top: 2

  CheckBox
    id: tick
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 95
    margin-top: 4
    font: verdana-11px-rounded
    text-offset: 17 -3

  BotTextEdit
    id: text
    anchors.left: tick.right
    anchors.right: value.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    margin-right: 3
    font: terminus-10px
    margin-top: 1
    margin-bottom: 1

  SpinBox
    id: value
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    margin-top: 1
    margin-bottom: 1
    width: 40
    minimum: 1
    maximum: 99
    step: 1
    editable: true
    focusable: true

DruidAttackSection < FlatPanel
  anchors.left: parent.left
  anchors.right: parent.right
  margin-top: 20
  padding: 5
  padding-left: 10
  layout:
    type: verticalBox
    fit-children: true

DruidAttackTitle < Label
  margin-left: 5
  width: 260
  font: verdana-11px-rounded
  color: #3fa043

DruidAttackWindow < MainWindow
  !text: tr('Druid Attack')
  size: 360 560
  padding: 15
  @onEscape: self:hide()

  DruidAttackSection
    id: area
    anchors.top: parent.top
    margin-top: 10

  DruidAttackTitle
    anchors.verticalCenter: area.top
    anchors.left: area.left
    text: Area attacks (spell or rune id / monsters)

  DruidAttackSection
    id: single
    anchors.top: area.bottom

  DruidAttackTitle
    anchors.verticalCenter: single.top
    anchors.left: single.left
    text: Target (spell or rune id / target HP % above)

  DruidAttackSection
    id: smart
    anchors.top: single.bottom

  DruidAttackTitle
    anchors.verticalCenter: smart.top
    anchors.left: smart.left
    text: Options

  Label
    id: status
    anchors.top: smart.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: separator.top
    margin-top: 8
    margin-bottom: 5
    text-wrap: true
    text-align: center
    font: verdana-11px-rounded

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 8

  Button
    id: resetButton
    !text: tr('Defaults')
    !tooltip: tr('Put every setting back to its default value.')
    font: cipsoftFont
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    size: 55 21
    margin-left: 5

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-right: 5
    @onClick: self:getParent():hide()
]])

local panelName = "druidAttack"
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Druid Attack')

  Button
    id: setup
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

]])
ui:setId(panelName)

if type(storage[panelName]) ~= "table" then
  storage[panelName] = {}
end
local config = storage[panelName]

local window = UI.createWindow("DruidAttackWindow")
window:hide()

ui.title:setOn(config.enabled)
ui.title.onClick = function(widget)
  config.enabled = not config.enabled
  widget:setOn(config.enabled)
end

ui.setup.onClick = function()
  window:show()
  window:raise()
  window:focus()
end

-- rows: "spell" = text + spin box, "number" = spin box, "check" = only tick
local rowStyles = {
  spell = "DruidAttackRow",
  number = "AlarmCheckBoxAndSpinBox",
  check = "AlarmCheckBox"
}
local rows = {}

local function addRow(parent, id, rowType, title, defaults, tooltip, minimum, maximum)
  local widget = UI.createWidget(rowStyles[rowType], parent)
  widget:setId(id)

  if type(config[id]) ~= "table" then
    config[id] = { enabled = defaults.enabled, text = defaults.text, value = defaults.value }
  end

  widget.tick:setText(title)
  if tooltip then
    widget.tick:setTooltip(tooltip)
  end
  if widget.value then
    if minimum then widget.value:setMinimum(minimum) end
    if maximum then widget.value:setMaximum(maximum) end
  end

  -- puts the saved values into the widgets (also used by the Defaults button)
  local function refresh()
    local entry = config[id]
    widget.tick:setChecked(entry.enabled)
    if widget.text then widget.text:setText(entry.text or "") end
    if widget.value then widget.value:setValue(entry.value or defaults.value or 0) end
  end
  refresh()

  widget.tick.onClick = function()
    config[id].enabled = not config[id].enabled
    widget.tick:setChecked(config[id].enabled)
  end
  if widget.text then
    widget.text.onTextChange = function(_, newText)
      config[id].text = newText
    end
  end
  if widget.value then
    widget.value.onValueChange = function(_, value)
      config[id].value = value
    end
  end

  table.insert(rows, { id = id, defaults = defaults, refresh = refresh })
end

-- area attacks: number = how many monsters are needed
addRow(window.area, "ue", "spell", "Big area", { enabled = true, text = "exevo gran mas frigo", value = 5 },
  "Eternal Winter (level 60, 1050 mana) or exevo gran mas tera, Wrath of Nature (level 55, 700 mana). Cast when this many monsters are around you.", 1, 15)
addRow(window.area, "wave", "spell", "Wave", { enabled = true, text = "exevo gran frigo hur", value = 3 },
  "Strong Ice Wave (level 40, 170 mana). Also exevo tera hur (level 38) or exevo frigo hur (level 18). Cast when this many monsters are in one direction.", 1, 10)
addRow(window.area, "areaRune", "spell", "Area rune", { enabled = true, text = "3161", value = 3 },
  "Rune id: 3161 avalanche, 3175 stone shower, 3191 great fireball, 3202 thunderstorm. Used on the tile that hits at least this many monsters.", 1, 15)

-- single target: number = target must have more HP % than this
addRow(window.single, "ultimate", "spell", "Ultimate strike", { enabled = true, text = "exori max frigo", value = 15 },
  "Ultimate Ice Strike (level 100, 100 mana) or exori max tera (level 90). Range 3 squares.", 1, 99)
addRow(window.single, "strong", "spell", "Strong strike", { enabled = true, text = "exori gran frigo", value = 10 },
  "Strong Ice Strike (level 80, 60 mana) or exori gran tera (level 70). Range 3 squares.", 1, 99)
addRow(window.single, "rune", "spell", "Target rune", { enabled = true, text = "3155", value = 1 },
  "Rune id: 3155 sudden death (level 45), 3158 icicle. Works from far away.", 1, 99)
addRow(window.single, "strike", "spell", "Strike", { enabled = true, text = "exori frigo", value = 1 },
  "Ice Strike (level 15, 20 mana) or exori tera (level 13). Range 3 squares.", 1, 99)

-- options
addRow(window.smart, "safe", "check", "Safe: no area attacks when players near", { enabled = true },
  "Area spells, waves and area runes wait while a player who is not in your party is on screen.")
addRow(window.smart, "keepMana", "number", "Attack spells only above MP %", { enabled = true, value = 30 },
  "Leaves mana for healing. Runes are still used.", 1, 99)
addRow(window.smart, "lowHp", "number", "No attack spells when HP % below", { enabled = true, value = 40 },
  "Lets the healer have the mana when you are in danger. Runes are still used.", 1, 99)
addRow(window.smart, "rotate", "check", "Turn to the best side for waves", { enabled = true })
addRow(window.smart, "delay", "number", "Min time between attacks (x100 ms)", { enabled = true, value = 10 },
  "10 = 1 second. Raise it to 20 on old servers that don't show cooldowns.", 2, 30)
addRow(window.smart, "pz", "check", "Pause in protection zone", { enabled = true })

window.resetButton.onClick = function()
  for _, row in ipairs(rows) do
    local d = row.defaults
    config[row.id] = { enabled = d.enabled, text = d.text, value = d.value }
    row.refresh()
  end
end

local function setStatus(text, color)
  window.status:setText(text)
  window.status:setColor(color or "#FFFFFF")
end
setStatus("Turn on the switch and attack a monster.", "#AAAAAA")

-- what is around us, collected once per tick
local function scan()
  local myPos = player:getPosition()
  local monsters, players = {}, 0
  for _, spec in ipairs(getSpectators()) do
    local pos = spec:getPosition()
    if pos and pos.z == myPos.z and not spec:isLocalPlayer() then
      if spec:isMonster() and spec:getHealthPercent() > 0 then
        table.insert(monsters, pos)
      elseif spec:isPlayer() and not (spec.isPartyMember and spec:isPartyMember()) then
        players = players + 1
      end
    end
  end
  return myPos, monsters, players
end

local function countAround(center, list, radiusSq)
  local n = 0
  for _, pos in ipairs(list) do
    local dx, dy = pos.x - center.x, pos.y - center.y
    if dx * dx + dy * dy <= radiusSq then n = n + 1 end
  end
  return n
end

-- monsters a wave would hit when facing dir (0 north, 1 east, 2 south, 3 west)
local dirs = { [0] = { 0, -1 }, [1] = { 1, 0 }, [2] = { 0, 1 }, [3] = { -1, 0 } }
local function countWave(myPos, list, dir)
  local fx, fy = dirs[dir][1], dirs[dir][2]
  local n = 0
  for _, pos in ipairs(list) do
    local dx, dy = pos.x - myPos.x, pos.y - myPos.y
    local forward = dx * fx + dy * fy
    local side = math.abs(dx * fy - dy * fx)
    if forward >= 1 and forward <= 5 and side <= math.floor((forward - 1) / 2) then
      n = n + 1
    end
  end
  return n
end

-- tile for an area rune that hits the most monsters (radius 3, like great fireball)
local function bestRuneTile(myPos, list)
  local best, bestCount = nil, 0
  for _, pos in ipairs(list) do
    if math.max(math.abs(pos.x - myPos.x), math.abs(pos.y - myPos.y)) <= 6 then
      local tile = g_map.getTile(pos)
      if tile and (not tile.canShoot or tile:canShoot()) then
        local n = countAround(pos, list, 10)
        if n > bestCount then
          best, bestCount = tile, n
        end
      end
    end
  end
  return best, bestCount
end

local lastAttack = 0
local lastAction = "nothing yet"

local function trySpell(entry, mpOk)
  local spell = (entry.text or ""):trim()
  if not entry.enabled or spell:len() == 0 or not mpOk then return false end
  if not canCast(spell) then return false end
  say(spell)
  lastAttack = now
  lastAction = spell
  return true
end

local function tryRune(entry, thing)
  if not entry.enabled or not thing then return false end
  local id = tonumber((entry.text or ""):trim())
  if not id or not findItem(id) then return false end
  useWith(id, thing)
  lastAttack = now
  lastAction = "rune " .. id
  return true
end

macro(100, function()
  if not config.enabled then return end
  if config.pz.enabled and isInPz() then return end
  local creature = target()
  if not creature then return end

  if now - lastAttack < (config.delay.value or 10) * 100 then return end
  if modules.game_cooldown and modules.game_cooldown.isGroupCooldownIconActive
    and modules.game_cooldown.isGroupCooldownIconActive(1) then return end

  local myPos, monsters, players = scan()
  local areaAllowed = creature:isMonster() and not (config.safe.enabled and players > 0)
  local mpOk = not (config.keepMana.enabled and manapercent() < (config.keepMana.value or 0))
  if config.lowHp.enabled and hppercent() < (config.lowHp.value or 0) then
    mpOk = false
  end

  -- 1. big area spell around us
  if areaAllowed and config.ue.enabled and countAround(myPos, monsters, 20) >= (config.ue.value or 5) then
    if trySpell(config.ue, mpOk) then return end
  end

  -- 2. wave in the best direction
  if areaAllowed and config.wave.enabled and mpOk then
    local bestDir, bestCount = player:getDirection(), -1
    local facing = countWave(myPos, monsters, bestDir)
    bestCount = facing
    for dir = 0, 3 do
      local n = countWave(myPos, monsters, dir)
      if n > bestCount then bestDir, bestCount = dir, n end
    end
    if bestCount >= (config.wave.value or 3) then
      if bestDir ~= player:getDirection() then
        if config.rotate.enabled then
          turn(bestDir)
          return
        end
      elseif trySpell(config.wave, mpOk) then
        return
      end
    end
  end

  -- 3. area rune on the best tile
  if areaAllowed and config.areaRune.enabled then
    local tile, n = bestRuneTile(myPos, monsters)
    if tile and n >= (config.areaRune.value or 3) and tryRune(config.areaRune, tile:getTopUseThing()) then
      return
    end
  end

  -- 4. single target
  if not creature:canShoot() then return end
  local targetHp = creature:getHealthPercent()
  local targetPos = creature:getPosition()
  local distance = math.max(math.abs(targetPos.x - myPos.x), math.abs(targetPos.y - myPos.y))
  local inStrikeRange = distance <= 3

  local function above(entry)
    return targetHp > (entry.value or 0)
  end

  if inStrikeRange and above(config.ultimate) and trySpell(config.ultimate, mpOk) then return end
  if inStrikeRange and above(config.strong) and trySpell(config.strong, mpOk) then return end
  if above(config.rune) and tryRune(config.rune, creature) then return end
  if inStrikeRange and above(config.strike) and trySpell(config.strike, mpOk) then return end
end)

-- status text in the setup window
macro(500, function()
  if not window:isVisible() then return end
  local _, monsters, players = scan()
  local text = string.format("Monsters near %d, players on screen %d\nLast attack: %s",
    #monsters, players, lastAction)
  local color = "#50FF50"
  if not config.enabled then
    color = "#AAAAAA"
  elseif AttackBot and AttackBot.isOn and AttackBot.isOn() then
    text = text .. "\nAttackBot is also on. Turn it off so they don't fight for the cooldown."
    color = "#FFAA00"
  end
  setStatus(text, color)
end)

UI.Separator()
