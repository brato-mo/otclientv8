-- @docclass Player

PlayerStates = {
  None = 0,
  Poison = 1,
  Burn = 2,
  Energy = 4,
  Drunk = 8,
  ManaShield = 16,
  Paralyze = 32,
  Haste = 64,
  Swords = 128,
  Drowning = 256,
  Freezing = 512,
  Dazzled = 1024,
  Cursed = 2048,
  PartyBuff = 4096,
  PzBlock = 8192,
  Pz = 16384,
  Bleeding = 32768,
  Hungry = 65536,
  -- newer states (Canary PlayerIcon), only sent by servers using
  -- 32-bit player states; LesserHex shares bit 16 with Hungry
  LesserHex = 65536,
  IntenseHex = 131072,
  GreaterHex = 262144,
  Rooted = 524288,
  Feared = 1048576,
  GoshnarTaint1 = 2097152,
  GoshnarTaint2 = 4194304,
  GoshnarTaint3 = 8388608,
  GoshnarTaint4 = 16777216,
  GoshnarTaint5 = 33554432,
  NewManaShield = 67108864,
  Agony = 134217728,
  Powerless = 268435456,
  MentorOther = 536870912
}

InventorySlotOther = 0
InventorySlotHead = 1
InventorySlotNeck = 2
InventorySlotBack = 3
InventorySlotBody = 4
InventorySlotRight = 5
InventorySlotLeft = 6
InventorySlotLeg = 7
InventorySlotFeet = 8
InventorySlotFinger = 9
InventorySlotAmmo = 10
InventorySlotPurse = 11

InventorySlotFirst = 1
InventorySlotLast = 10

function Player:isPartyLeader()
  local shield = self:getShield()
  return (shield == ShieldYellow or
          shield == ShieldYellowSharedExp or
          shield == ShieldYellowNoSharedExpBlink or
          shield == ShieldYellowNoSharedExp)
end

function Player:isPartyMember()
  local shield = self:getShield()
  return (shield == ShieldYellow or
          shield == ShieldYellowSharedExp or
          shield == ShieldYellowNoSharedExpBlink or
          shield == ShieldYellowNoSharedExp or
          shield == ShieldBlueSharedExp or
          shield == ShieldBlueNoSharedExpBlink or
          shield == ShieldBlueNoSharedExp or
          shield == ShieldBlue)
end

function Player:isPartySharedExperienceActive()
  local shield = self:getShield()
  return (shield == ShieldYellowSharedExp or
          shield == ShieldYellowNoSharedExpBlink or
          shield == ShieldYellowNoSharedExp or
          shield == ShieldBlueSharedExp or
          shield == ShieldBlueNoSharedExpBlink or
          shield == ShieldBlueNoSharedExp)
end

function Player:hasVip(creatureName)
  for id, vip in pairs(g_game.getVips()) do
    if (vip[1] == creatureName) then return true end
  end
  return false
end

function Player:isMounted()
  local outfit = self:getOutfit()
  return outfit.mount ~= nil and outfit.mount > 0
end

function Player:toggleMount()
  if g_game.getFeature(GamePlayerMounts) then
    g_game.mount(not self:isMounted())
  end
end

function Player:mount()
  if g_game.getFeature(GamePlayerMounts) then
    g_game.mount(true)
  end
end

function Player:dismount()
  if g_game.getFeature(GamePlayerMounts) then
    g_game.mount(false)
  end
end

function Player:getItem(itemId, subType)
  return g_game.findPlayerItem(itemId, subType or -1)
end

function Player:getItems(itemId, subType)
  local subType = subType or -1

  local items = {}
  for i=InventorySlotFirst,InventorySlotLast do
    local item = self:getInventoryItem(i)
    if item and item:getId() == itemId and (subType == -1 or item:getSubType() == subType) then
      table.insert(items, item)
    end
  end

  for i, container in pairs(g_game.getContainers()) do
    for j, item in pairs(container:getItems()) do
      if item:getId() == itemId and (subType == -1 or item:getSubType() == subType) then
        item.container = container
        table.insert(items, item)
      end
    end
  end
  return items
end

function Player:getItemsCount(itemId)
  local items, count = self:getItems(itemId), 0
  for i=1,#items do
    count = count + items[i]:getCount()
  end
  return count
end

function Player:hasState(state, states)
  if not states then
    states = self:getStates()
  end
  if not state or state == 0 or not states then
    return false
  end
  -- true when every bit of state is set (works for single and combined flags)
  return bit32.band(states, state) == state
end

-- Vocations as sent to the client (Canary VOCATION_*_CIP, TFS clientid).
-- Promoted vocations are base id + 10. Custom servers may use other ids.
ClientVocations = {
  None = 0,
  Knight = 1,
  Paladin = 2,
  Sorcerer = 3,
  Druid = 4,
  Monk = 5
}

-- client vocation id -> server vocation id (ids used in SpellInfo / VocationNames)
local clientToServerVocation = {
  [1] = 4, [2] = 3, [3] = 1, [4] = 2, [5] = 9,
  [11] = 8, [12] = 7, [13] = 5, [14] = 6, [15] = 10
}

function getServerVocationId(clientVocationId)
  return clientToServerVocation[clientVocationId] or 0
end

function getVocationName(clientVocationId)
  local serverId = getServerVocationId(clientVocationId)
  return VocationNames and VocationNames[serverId] or 'None'
end

-- base vocation (1-5, see ClientVocations) without promotion
function getBaseVocation(clientVocationId)
  if not clientVocationId or clientVocationId <= 0 then return 0 end
  return clientVocationId > 10 and clientVocationId - 10 or clientVocationId
end

function LocalPlayer:getServerVocation()
  return getServerVocationId(self:getVocation())
end

function LocalPlayer:getVocationName()
  return getVocationName(self:getVocation())
end

function LocalPlayer:isPromoted()
  return self:getVocation() > 10
end

function LocalPlayer:isKnight() return getBaseVocation(self:getVocation()) == ClientVocations.Knight end
function LocalPlayer:isPaladin() return getBaseVocation(self:getVocation()) == ClientVocations.Paladin end
function LocalPlayer:isSorcerer() return getBaseVocation(self:getVocation()) == ClientVocations.Sorcerer end
function LocalPlayer:isDruid() return getBaseVocation(self:getVocation()) == ClientVocations.Druid end
function LocalPlayer:isMonk() return getBaseVocation(self:getVocation()) == ClientVocations.Monk end
function LocalPlayer:isMage()
  local base = getBaseVocation(self:getVocation())
  return base == ClientVocations.Sorcerer or base == ClientVocations.Druid
end

function LocalPlayer:getHealthPercentExact()
  local maxHealth = self:getMaxHealth()
  if not maxHealth or maxHealth <= 0 then return 0 end
  return self:getHealth() * 100 / maxHealth
end

function LocalPlayer:getManaPercentExact()
  local maxMana = self:getMaxMana()
  if not maxMana or maxMana <= 0 then return 0 end
  return self:getMana() * 100 / maxMana
end

-- total experience needed to reach a level (official Tibia formula)
function getExperienceForLevel(level)
  level = level - 1
  return math.floor((50 * level * level * level - 150 * level * level + 400 * level) / 3)
end

function LocalPlayer:getExperienceToNextLevel()
  return math.max(0, getExperienceForLevel(self:getLevel() + 1) - self:getExperience())
end

-- stamina is in minutes; 'green' stamina (bonus exp) is above 39h, 'orange' below 14h
function LocalPlayer:hasGreenStamina()
  return self:getStamina() > 39 * 60
end

function LocalPlayer:hasLowStamina()
  return self:getStamina() <= 14 * 60
end

function LocalPlayer:getStaminaText()
  local stamina = self:getStamina()
  return string.format('%02d:%02d', math.floor(stamina / 60), stamina % 60)
end

-- weight in oz, same unit as getFreeCapacity()
function LocalPlayer:canCarry(weight)
  return self:getFreeCapacity() >= weight
end
