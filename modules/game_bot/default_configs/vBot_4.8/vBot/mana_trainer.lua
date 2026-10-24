setDefaultTab("Tools")

-- Mana Trainer: trains magic level while AFK. When mana is above the chosen
-- percent it casts the chosen spell (for example "exura" or "utevo lux").
-- It waits while monsters are near, eats food when hungry (uses the
-- "Eatable items" list from the HP tab) and turns around every few minutes
-- so the server does not kick you for being idle.

local panelName = "manaTrainer"
if type(storage[panelName]) ~= "table" then
  storage[panelName] = {
    spell = "exura",
    manaPercent = 90,
    idleMinutes = 10,
    eatFood = true
  }
end
local config = storage[panelName]

local lastTurn = now

macro(500, "Mana Trainer", function()
  -- eat food when hungry
  if config.eatFood and player:getRegenerationTime() <= 400 and type(storage.foodItems) == "table" then
    for _, container in pairs(g_game.getContainers()) do
      for __, item in ipairs(container:getItems()) do
        for ___, food in ipairs(storage.foodItems) do
          if item:getId() == food.id then
            g_game.use(item)
            return delay(1000)
          end
        end
      end
    end
  end

  -- anti idle: turn to a random side every few minutes
  local idleMinutes = tonumber(config.idleMinutes) or 0
  if idleMinutes > 0 and now - lastTurn > idleMinutes * 60 * 1000 then
    turn(math.random(0, 3))
    lastTurn = now
    return delay(1000)
  end

  -- do not train while monsters are near, healing comes first
  if getMonsters(7) > 0 then return end

  local spell = config.spell
  if type(spell) ~= "string" or spell:len() == 0 then return end
  if manapercent() < (tonumber(config.manaPercent) or 90) then return end
  if not canCast(spell) then return end

  say(spell)
  delay(2000)
end)

UI.Label("Training spell:")
UI.TextEdit(config.spell, function(widget, text)
  config.spell = text
end)

UI.Label("Cast when mana % is at least:")
UI.TextEdit(tostring(config.manaPercent), function(widget, text)
  config.manaPercent = tonumber(text) or 90
end)

UI.Label("Anti idle every X minutes (0 = off):")
UI.TextEdit(tostring(config.idleMinutes), function(widget, text)
  config.idleMinutes = tonumber(text) or 0
end)

UI.Button("Eat food: " .. (config.eatFood and "ON" or "OFF"), function(widget)
  config.eatFood = not config.eatFood
  widget:setText("Eat food: " .. (config.eatFood and "ON" or "OFF"))
end)

UI.Separator()
