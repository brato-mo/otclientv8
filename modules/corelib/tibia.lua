-- @docclass math
-- Helpers for numbers that show up all the time in Tibia: gold amounts
-- written as k / kk / kkk, hunt durations and "per hour" rates.
-- They live in the math library, so vBot scripts can use them too.

local goldSuffixes = {
  { 1000000000, 'kkk' },
  { 1000000, 'kk' },
  { 1000, 'k' },
}

-- math.formatGold(1500000) -> "1.5kk", math.formatGold(250000) -> "250k",
-- math.formatGold(999) -> "999". The value is cut, not rounded, so 999999
-- never turns into "1000k".
function math.formatGold(amount, decimals)
  amount = tonumber(amount) or 0
  decimals = math.max(0, math.floor(tonumber(decimals) or 1))
  local sign = amount < 0 and '-' or ''
  amount = math.abs(amount)
  for _, suffix in ipairs(goldSuffixes) do
    if amount >= suffix[1] then
      local mult = 10 ^ decimals
      local value = math.floor(amount / suffix[1] * mult + 1e-6) / mult
      local text = string.format('%.' .. decimals .. 'f', value)
      if text:find('%.') then
        text = text:gsub('0+$', ''):gsub('%.$', '')
      end
      return sign .. text .. suffix[2]
    end
  end
  return sign .. tostring(math.floor(amount))
end

-- math.parseGold("1.5kk") -> 1500000, also "100k", "2,500", "1,5kk",
-- "3kkk", "2m", "1b", "500gp" and plain numbers. Returns nil when the text
-- is not an amount.
function math.parseGold(text)
  if type(text) == 'number' then return math.floor(text) end
  if type(text) ~= 'string' then return nil end
  local s = text:lower():gsub('[%s_]', '')
  s = s:gsub('gold$', ''):gsub('gp$', '')
  local number, suffix = s:match('^(%-?[%d%.,]+)([kmb]*)$')
  if not number then return nil end

  local mult = 1
  if suffix == 'm' then
    mult = 1000000
  elseif suffix == 'b' then
    mult = 1000000000
  elseif suffix:match('^k+$') then
    mult = 1000 ^ #suffix
  elseif suffix ~= '' then
    return nil
  end

  if suffix ~= '' then
    -- "1,5kk" uses a decimal comma
    number = number:gsub(',', '.')
  else
    -- "2,500" or "2.500.000" use thousand separators
    number = number:gsub(',', '')
    if select(2, number:gsub('%.', '')) > 1 then
      number = number:gsub('%.', '')
    end
  end

  local value = tonumber(number)
  if not value then return nil end
  value = value * mult
  if value < 0 then
    return -math.floor(-value + 0.5)
  end
  return math.floor(value + 0.5)
end

-- math.formatDuration(3725) -> "1h 02m 05s", 90061 -> "1d 1h 01m",
-- 65 -> "1m 05s", 9 -> "9s". Takes seconds.
function math.formatDuration(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local days = math.floor(seconds / 86400)
  local hours = math.floor(seconds % 86400 / 3600)
  local minutes = math.floor(seconds % 3600 / 60)
  local secs = seconds % 60
  if days > 0 then
    return string.format('%dd %dh %02dm', days, hours, minutes)
  elseif hours > 0 then
    return string.format('%dh %02dm %02ds', hours, minutes, secs)
  elseif minutes > 0 then
    return string.format('%dm %02ds', minutes, secs)
  end
  return string.format('%ds', secs)
end

-- math.perHour(150000, 1800) -> 300000: turns a total gained in
-- elapsedSeconds into an hourly rate (exp/h, profit/h, kills/h).
function math.perHour(value, elapsedSeconds)
  value = tonumber(value) or 0
  elapsedSeconds = tonumber(elapsedSeconds) or 0
  if elapsedSeconds <= 0 then return 0 end
  return math.floor(value * 3600 / elapsedSeconds)
end
