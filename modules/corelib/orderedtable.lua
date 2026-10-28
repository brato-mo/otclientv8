local function orderedKeyLess(a, b)
  local ta, tb = type(a), type(b)
  if ta == tb and (ta == 'number' or ta == 'string') then
    return a < b
  end
  -- mixed key types: numbers first, everything else by its string form
  if ta == 'number' then return true end
  if tb == 'number' then return false end
  return tostring(a) < tostring(b)
end

function __genOrderedIndex( t )
  local orderedIndex = {}
  for key in pairs(t) do
    if key ~= '__orderedIndex' then
      table.insert( orderedIndex, key )
    end
  end
  table.sort( orderedIndex, orderedKeyLess )
  return orderedIndex
end

function orderedNext(t, state)
  -- Equivalent of the next function, but returns the keys in the alphabetic
  -- order. We use a temporary ordered key table that is stored in the
  -- table being iterated.
  local key = nil
  if state == nil then
    -- the first time, generate the index
    t.__orderedIndex = __genOrderedIndex( t )
    key = t.__orderedIndex[1]
  elseif t.__orderedIndex then
    -- fetch the next value
    local index = t.__orderedIndex
    for i = 1, #index do
      if index[i] == state then
        key = index[i + 1]
        break
      end
    end
  end

  if key ~= nil then
    return key, t[key]
  end

  -- no more value to return, cleanup
  t.__orderedIndex = nil
  return
end

function orderedPairs(t)
  -- Equivalent of the pairs() function on tables. Allows to iterate
  -- in order. The key list is kept in a closure, so t is not modified
  -- and nested or interrupted loops over the same table are safe.
  local keys = __genOrderedIndex(t)
  local i = 0
  return function()
    i = i + 1
    local key = keys[i]
    if key ~= nil then
      return key, t[key]
    end
  end, t, nil
end
