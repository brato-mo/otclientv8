setDefaultTab("HP")

-- Druid Healer: one switch that heals an (elder) druid, its friends and party.
-- Works as a file in vBot or pasted alone into an empty script tab.
--
-- How it decides (every 100 ms):
--  1. It guesses your HP a moment ahead from the damage you took in the last
--     3 seconds ("Predict damage"), so it heals before a big hit lands.
--  2. With many monsters around it heals earlier ("Heal earlier when ...").
--  3. Spells: the strongest tier whose HP % you are under is cast. If that
--     spell can't be cast (cooldown, mana, level) the next weaker one is tried.
--     exura max vita needs level 300, below that exura vita is used.
--     Light heal is skipped when your mana is under "Save mana".
--  4. When your own HP is safe it heals friends: names in the list and, if
--     ticked, party members on screen. Several hurt friends close to you get
--     mass healing, a friend in deep trouble gets Nature's Embrace (level 300).
--  5. Potions run at the same time (they have their own exhaust): health
--     potion when HP is low, mana potion when mana is low, and a mana potion
--     first when mana is so low that the heal spells can't be cast.
--  6. When HP is safe it cures paralysis, poison, burning, energy and bleeding.
--
-- Default potion ids: 266 health, 7876 small health,
-- 23373 ultimate mana, 238 great mana, 237 strong mana, 268 mana.
-- Turn off HealBot (or its druid rows) so both don't heal at once.

g_ui.loadUIFromString([[
DruidHealRow < Panel
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

DruidHealerSection < FlatPanel
  anchors.left: parent.left
  anchors.right: parent.right
  margin-top: 20
  padding: 5
  padding-left: 10
  layout:
    type: verticalBox
    fit-children: true

DruidHealerTitle < Label
  margin-left: 5
  width: 250
  font: verdana-11px-rounded
  color: #3fa043

DruidHealerWindow < MainWindow
  !text: tr('Druid Healer')
  size: 360 680
  padding: 15
  @onEscape: self:hide()

  DruidHealerSection
    id: spells
    anchors.top: parent.top
    margin-top: 10

  DruidHealerTitle
    anchors.verticalCenter: spells.top
    anchors.left: spells.left
    text: Healing spells (spell / HP %)

  DruidHealerSection
    id: friends
    anchors.top: spells.bottom

  DruidHealerTitle
    anchors.verticalCenter: friends.top
    anchors.left: friends.left
    text: Friends and party (names / HP %)

  DruidHealerSection
    id: potions
    anchors.top: friends.bottom

  DruidHealerTitle
    anchors.verticalCenter: potions.top
    anchors.left: potions.left
    text: Potions (item ids, best first / %)

  DruidHealerSection
    id: smart
    anchors.top: potions.bottom

  DruidHealerTitle
    anchors.verticalCenter: smart.top
    anchors.left: smart.left
    text: Smart options

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

local panelName = "druidHealer"
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Druid Healer')

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

local window = UI.createWindow("DruidHealerWindow")
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

-- rows: "spell" = text + spin box, "number" = spin box, "text" = text, "check" = only tick
local rowStyles = {
  spell = "DruidHealRow",
  number = "AlarmCheckBoxAndSpinBox",
  text = "AlarmCheckBoxAndTextEdit",
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

-- healing spells, strongest first
addRow(window.spells, "emergency", "spell", "Emergency", { enabled = true, text = "exura max vita", value = 35 },
  "Restoration (level 300, 260 mana). Below level 300 the next spell is used. Cast when HP is under this %.")
addRow(window.spells, "strong", "spell", "Strong heal", { enabled = true, text = "exura vita", value = 55 },
  "Ultimate Healing (level 30, 160 mana). Cast when HP is under this %.")
addRow(window.spells, "light", "spell", "Light heal", { enabled = true, text = "exura gran", value = 85 },
  "Intense Healing (level 20, 70 mana) to top up HP. Cast when HP is under this %.")

-- friends and party
addRow(window.friends, "friend", "spell", "Heal friends", { enabled = false, text = "", value = 60 },
  "Names separated by comma. exura sio \"name\" (level 18, 120 mana) when a friend on screen is under this HP %.")
addRow(window.friends, "party", "check", "Also heal party members", { enabled = true },
  "Party members on screen are healed like the names above.")
addRow(window.friends, "mass", "number", "Mass healing when hurt friends near >=", { enabled = true, value = 2 },
  "exura gran mas res (level 36, 150 mana) when this many hurt friends are within 3 squares. You count too when you are hurt.", 1, 10)
addRow(window.friends, "embrace", "number", "Nature's Embrace when friend HP % <", { enabled = true, value = 30 },
  "exura gran sio (level 300, 400 mana, 1 min cooldown) for a friend in deep trouble.", 1, 99)

-- potions (druids can't use strong/great health potions)
addRow(window.potions, "healthPotion", "spell", "Health potion", { enabled = true, text = "266, 7876", value = 40 },
  "Item ids separated by comma, best first. Used when HP is under this %.")
addRow(window.potions, "manaPotion", "spell", "Mana potion", { enabled = true, text = "23373, 238, 237, 268", value = 60 },
  "Item ids separated by comma, best first. Used when mana is under this %.")

-- smart options
addRow(window.smart, "predict", "number", "Predict damage (x100 ms ahead)", { enabled = true, value = 6 },
  "Heals for the HP you will most likely have this long from now, based on the damage of the last 3 seconds. 6 = 0.6 s.", 1, 20)
addRow(window.smart, "crowd", "number", "Heal 10% earlier with monsters near >=", { enabled = true, value = 4 },
  "When this many monsters are within 3 squares, every HP % above is raised by 10.", 1, 15)
addRow(window.smart, "saveMana", "number", "Save mana: light heal only above MP %", { enabled = true, value = 30 },
  "Keeps mana for the big heals. Emergency and strong heal are never held back.", 1, 99)
addRow(window.smart, "lowMana", "number", "Mana potion first when MP % below", { enabled = true, value = 25 },
  "When mana is this low, a mana potion is used before a health potion (unless HP is in emergency).", 1, 99)
addRow(window.smart, "paralyze", "text", "Cure paralysis with", { enabled = true, text = "utani hur" })
addRow(window.smart, "poison", "check", "Cure poison (exana pox)", { enabled = true })
addRow(window.smart, "burn", "check", "Cure burning (exana flam, level 30)", { enabled = true })
addRow(window.smart, "energy", "check", "Cure energy (exana vis, level 22)", { enabled = true })
addRow(window.smart, "bleed", "check", "Cure bleeding (exana kor, level 45)", { enabled = true })
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
setStatus("Turn on the switch to start healing.", "#AAAAAA")

-- "a, b" -> list, cached so it's not parsed every tick
local listCache = {}
local function parseList(text, asNumbers)
  text = text or ""
  local key = (asNumbers and "n:" or "s:") .. text
  if listCache[key] then return listCache[key] end
  local list = {}
  for _, part in ipairs(string.split(text, ",")) do
    part = part:trim()
    if asNumbers then
      local id = tonumber(part)
      if id then table.insert(list, id) end
    elseif part:len() > 0 then
      list[part:lower()] = true
    end
  end
  listCache[key] = list
  return list
end

local lastPotion = 0
local function usePotion(entry)
  if not entry.enabled then return false end
  if vBot.isUsingPotion or now - lastPotion < 1000 then return false end
  for _, id in ipairs(parseList(entry.text, true)) do
    if findItem(id) then
      g_game.useInventoryItemWith(id, player)
      lastPotion = now
      return true
    end
  end
  return false
end

-- target: optional player name, the spell is then said as: words "name"
local lastSpell = 0
local function castSpell(spell, target)
  spell = (spell or ""):trim()
  if spell:len() == 0 then return false end
  if now - lastSpell < 400 then return false end
  if not canCast(spell) then return false end
  if target then
    say(spell .. ' "' .. target .. '"')
  else
    say(spell)
  end
  lastSpell = now
  return true
end

-- damage per second from the last 3 seconds, made safe for 0/inf/nan
local function damagePerSecond()
  local dps = burstDamageValue()
  if dps ~= dps or dps < 0 then return 0 end
  return math.min(dps, maxhp() * 2)
end

-- hurt friends on screen (same floor), most hurt first
local function hurtFriends(threshold)
  local names = config.friend.enabled and parseList(config.friend.text, false) or {}
  local useParty = config.party.enabled
  local myPos = player:getPosition()
  local result = {}
  for _, spec in ipairs(getSpectators()) do
    if spec:isPlayer() and not spec:isLocalPlayer() then
      local isFriend = names[spec:getName():lower()]
      if not isFriend and useParty and spec.isPartyMember and spec:isPartyMember() then
        isFriend = true
      end
      local pos = spec:getPosition()
      if isFriend and pos and pos.z == myPos.z then
        local hpPercent = spec:getHealthPercent()
        if hpPercent > 0 and hpPercent <= threshold then
          local distance = math.max(math.abs(pos.x - myPos.x), math.abs(pos.y - myPos.y))
          table.insert(result, { name = spec:getName(), hp = hpPercent, distance = distance })
        end
      end
    end
  end
  table.sort(result, function(a, b) return a.hp < b.hp end)
  return result
end

local tiers = { "emergency", "strong", "light" }
local lastStatus = 0
local lastAction = "nothing yet"

macro(100, function()
  if not config.enabled then return end
  if config.pz.enabled and isInPz() then return end

  local maxHealth = math.max(maxhp(), 1)
  local mp = manapercent()
  local dps = damagePerSecond()

  -- HP % we will likely have a moment from now
  local predicted = hp()
  if config.predict.enabled then
    predicted = predicted - dps * (config.predict.value or 6) / 10
  end
  local hpp = math.max(0, predicted * 100 / maxHealth)

  local bonus = 0
  if config.crowd.enabled and getMonsters(3) >= (config.crowd.value or 4) then
    bonus = 10
  end

  local function under(id)
    return config[id].enabled and hpp <= (config[id].value or 0) + bonus
  end

  -- own healing: find the strongest tier we need, fall back to weaker ones
  local healed = false
  for i, id in ipairs(tiers) do
    if under(id) then
      for j = i, #tiers do
        local tier = config[tiers[j]]
        local allowed = tier.enabled
        if tiers[j] == "light" and i == #tiers and config.saveMana.enabled and mp < (config.saveMana.value or 0) then
          allowed = false
        end
        if allowed and castSpell(tier.text) then
          healed = true
          lastAction = tier.text
          break
        end
      end
      break
    end
  end

  -- friends, only when our own HP is not in danger
  if not healed and not under("strong") and (config.friend.enabled or config.party.enabled) then
    local friendLimit = config.friend.value or 60
    local friends = hurtFriends(friendLimit)
    local worst = friends[1]
    if worst then
      local near = 0
      for _, friend in ipairs(friends) do
        if friend.distance <= 3 then near = near + 1 end
      end
      if hppercent() <= friendLimit then near = near + 1 end

      if config.embrace.enabled and worst.hp < (config.embrace.value or 30) and castSpell("exura gran sio", worst.name) then
        healed = true
        lastAction = "exura gran sio " .. worst.name
      elseif config.mass.enabled and near >= (config.mass.value or 2) and castSpell("exura gran mas res") then
        healed = true
        lastAction = "exura gran mas res"
      elseif castSpell("exura sio", worst.name) then
        healed = true
        lastAction = "exura sio " .. worst.name
      end
    end
  end

  -- cures, only when HP is not in danger
  if not healed and not under("strong") then
    local cure = nil
    if config.paralyze.enabled and isParalyzed() then
      cure = config.paralyze.text
    elseif config.poison.enabled and isPoisioned() then
      cure = "exana pox"
    elseif config.burn.enabled and isBurning() then
      cure = "exana flam"
    elseif config.energy.enabled and isEnergized() then
      cure = "exana vis"
    elseif config.bleed.enabled and isBleeding() then
      cure = "exana kor"
    end
    if cure and castSpell(cure) then
      lastAction = cure
    end
  end

  -- potions have their own exhaust, so they can go together with a spell
  local hpPotion = config.healthPotion
  local mpPotion = config.manaPotion
  local needHp = hpPotion.enabled and hpp <= (hpPotion.value or 0) + bonus
  local needMp = mpPotion.enabled and mp <= (mpPotion.value or 0)
  local manaCritical = config.lowMana.enabled and mp < (config.lowMana.value or 0)

  if under("emergency") and needHp then
    if usePotion(hpPotion) then lastAction = "health potion" end
  elseif manaCritical and needMp then
    if usePotion(mpPotion) then lastAction = "mana potion" end
  elseif needHp then
    if usePotion(hpPotion) then lastAction = "health potion" end
  elseif needMp then
    if usePotion(mpPotion) then lastAction = "mana potion" end
  end

  -- status text in the setup window, twice per second is enough
  if window:isVisible() and now - lastStatus > 500 then
    lastStatus = now
    local text = string.format("HP now %d%%, expected %d%%, damage %d/s\nMana %d%%. Last action: %s",
      hppercent(), math.floor(hpp), math.floor(dps), mp, lastAction)
    local color = "#50FF50"
    if HealBot and HealBot.isOn and HealBot.isOn() then
      text = text .. "\nHealBot is also on. Turn it off to avoid double heals."
      color = "#FFAA00"
    end
    setStatus(text, color)
  end
end)

UI.Separator()
