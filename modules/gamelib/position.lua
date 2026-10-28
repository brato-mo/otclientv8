Position = {}

function Position.equals(pos1, pos2)
  return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

function Position.greaterThan(pos1, pos2, orEqualTo)
  if orEqualTo then
    return pos1.x >= pos2.x or pos1.y >= pos2.y or pos1.z >= pos2.z
  else
    return pos1.x > pos2.x or pos1.y > pos2.y or pos1.z > pos2.z
  end
end

function Position.lessThan(pos1, pos2, orEqualTo)
  if orEqualTo then
    return pos1.x <= pos2.x or pos1.y <= pos2.y or pos1.z <= pos2.z
  else
    return pos1.x < pos2.x or pos1.y < pos2.y or pos1.z < pos2.z
  end
end

function Position.isInRange(pos1, pos2, xRange, yRange)
  return math.abs(pos1.x-pos2.x) <= xRange and math.abs(pos1.y-pos2.y) <= yRange and pos1.z == pos2.z;
end

function Position.isValid(pos)
  return type(pos) == 'table' and pos.x ~= nil and pos.y ~= nil and pos.z ~= nil and
         not (pos.x == 65535 and pos.y == 65535 and pos.z == 255)
end

function Position.distance(pos1, pos2)
  return math.sqrt(math.pow((pos2.x - pos1.x), 2) + math.pow((pos2.y - pos1.y), 2))
end

function Position.manhattanDistance(pos1, pos2)
  return math.abs(pos2.x - pos1.x) + math.abs(pos2.y - pos1.y)
end

-- Tibia distance: diagonal steps count as 1 (same as spell/rune range)
function Position.chebyshevDistance(pos1, pos2)
  return math.max(math.abs(pos2.x - pos1.x), math.abs(pos2.y - pos1.y))
end

function Position.isInRangeZ(pos1, pos2, range)
  return pos1.z == pos2.z and Position.chebyshevDistance(pos1, pos2) <= range
end

function Position.copy(pos)
  return {x = pos.x, y = pos.y, z = pos.z}
end

local directionOffsets = {
  [Directions.North] = {0, -1},
  [Directions.East] = {1, 0},
  [Directions.South] = {0, 1},
  [Directions.West] = {-1, 0},
  [Directions.NorthEast] = {1, -1},
  [Directions.SouthEast] = {1, 1},
  [Directions.SouthWest] = {-1, 1},
  [Directions.NorthWest] = {-1, -1}
}

-- new position moved 'steps' tiles (default 1) towards direction
function Position.translatedToDirection(pos, direction, steps)
  local offset = directionOffsets[direction]
  if not offset then return Position.copy(pos) end
  steps = steps or 1
  return {x = pos.x + offset[1] * steps, y = pos.y + offset[2] * steps, z = pos.z}
end

-- direction to walk/turn from pos1 towards pos2 (nil if same tile)
function Position.getDirectionFromTo(pos1, pos2)
  local dx, dy = pos2.x - pos1.x, pos2.y - pos1.y
  if dx == 0 and dy == 0 then return nil end
  local sx = dx > 0 and 1 or (dx < 0 and -1 or 0)
  local sy = dy > 0 and 1 or (dy < 0 and -1 or 0)
  -- prefer a straight direction when the target is mostly on one axis
  if math.abs(dx) > 2 * math.abs(dy) then sy = 0 end
  if math.abs(dy) > 2 * math.abs(dx) then sx = 0 end
  for dir, offset in pairs(directionOffsets) do
    if offset[1] == sx and offset[2] == sy then
      return dir
    end
  end
end

function Position.toString(pos)
  return string.format('%d, %d, %d', pos.x, pos.y, pos.z)
end

-- parses '32369, 32241, 7', '32369 32241 7' or '{x=32369, y=32241, z=7}'
function Position.fromString(text)
  if type(text) ~= 'string' then return nil end
  local x, y, z = text:match('(%d+)%D+(%d+)%D+(%d+)')
  if not x then return nil end
  return {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
end
