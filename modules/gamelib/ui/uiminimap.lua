function UIMinimap:onCreate()
  self.autowalk = true
end

function UIMinimap:onSetup()
  self.flagWindow = nil
  self.flags = {}
  self.flagIndex = {}
  self.alternatives = {}
  self.onAddAutomapFlag = function(pos, icon, description) self:addFlag(pos, icon, description) end
  self.onRemoveAutomapFlag = function(pos, icon, description) self:removeFlag(pos, icon, description) end
  connect(g_game, {
    onAddAutomapFlag = self.onAddAutomapFlag,
    onRemoveAutomapFlag = self.onRemoveAutomapFlag,
  })
end

function UIMinimap:onDestroy()
  self:clearPresetFlags()
  for _,widget in pairs(self.alternatives) do
    widget:destroy()
  end
  self.alternatives = {}
  disconnect(g_game, {
    onAddAutomapFlag = self.onAddAutomapFlag,
    onRemoveAutomapFlag = self.onRemoveAutomapFlag,
  })
  self:destroyFlagWindow()
  self.flags = {}
  self.flagIndex = {}
end

function UIMinimap:onVisibilityChange()
  if not self:isVisible() then
    self:destroyFlagWindow()
  end
end

function UIMinimap:onCameraPositionChange(cameraPos, oldPos)
  if self.cross then
    self:setCrossPosition(self.cross.pos)
  end
  self:updatePresetFlags()
end

function UIMinimap:hideFloor()
  self.floorUpWidget:hide()
  self.floorDownWidget:hide()
end

function UIMinimap:hideZoom()
  self.zoomInWidget:hide()
  self.zoomOutWidget:hide()
end

function UIMinimap:disableAutoWalk()
  self.autowalk = false
end

function UIMinimap:load()
  local settings = g_settings.getNode('Minimap')
  if settings then
    if settings.flags then
      for _,flag in pairs(settings.flags) do
        self:addFlag(flag.position, flag.icon, flag.description)
      end
    end
    self:setZoom(settings.zoom)
  end
end

function UIMinimap:save()
  local settings = { flags={} }
  for _,flag in pairs(self.flags) do
    if not flag.temporary then
      table.insert(settings.flags, {
        position = flag.pos,
        icon = flag.icon,
        description = flag.description,
      })
    end
  end
  settings.zoom = self:getZoom()
  g_settings.setNode('Minimap', settings)
end

local function onFlagMouseRelease(widget, pos, button)
  if button == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Delete mark'), function() widget:destroy() end)
    menu:display(pos)
    return true
  end
  return false
end

function UIMinimap:setCrossPosition(pos)
  local cross = self.cross
  if not self.cross then
    cross = g_ui.createWidget('MinimapCross', self)
    cross:setIcon('/images/game/minimap/cross')
    self.cross = cross
  end

  if pos then
    pos = {x = pos.x, y = pos.y, z = self:getCameraPosition().z}
  end
  cross.pos = pos
  if pos then
    self:centerInPosition(cross, pos)
  else
    cross:breakAnchors()
  end
end

function UIMinimap:addFlag(pos, icon, description, temporary)
  if not pos or not icon then return end
  local flag = self:getFlag(pos, icon, description)
  if flag or not icon then
    return
  end
  temporary = temporary or false

  flag = g_ui.createWidget('MinimapFlag')
  self:insertChild(1, flag)
  flag.pos = pos
  flag.description = description
  flag.icon = icon
  flag.temporary = temporary
  if type(tonumber(icon)) == 'number' then
    flag:setIcon('/images/game/minimap/flag' .. icon)
  else
    flag:setIcon(resolvepath(icon, 1))
  end
  flag:setTooltip(description)
  flag.onMouseRelease = onFlagMouseRelease
  local key = pos.x .. ',' .. pos.y .. ',' .. pos.z
  flag.onDestroy = function()
    table.removevalue(self.flags, flag)
    if self.flagIndex[key] == flag then self.flagIndex[key] = nil end
  end
  table.insert(self.flags, flag)
  self.flagIndex[key] = flag
  self:centerInPosition(flag, pos)
end

function UIMinimap:addAlternativeWidget(widget, pos, maxZoom, minZoom)
  widget.pos = pos
  widget.maxZoom = maxZoom or 0
  widget.minZoom = minZoom
  table.insert(self.alternatives, widget)
end

function UIMinimap:setAlternativeWidgetsVisible(show)
  local layout = self:getLayout()
  layout:disableUpdates()
  for _,widget in pairs(self.alternatives) do
    if show then
      self:insertChild(1, widget)
      self:centerInPosition(widget, widget.pos)
    else
      self:removeChild(widget)
    end
  end
  layout:enableUpdates()
  layout:update()
end

function UIMinimap:onZoomChange(zoom)
  for _,widget in pairs(self.alternatives) do
    if (not widget.minZoom or widget.minZoom >= zoom) and widget.maxZoom <= zoom then
      widget:show()
    else
      widget:hide()
    end
  end
end

function UIMinimap:getFlag(pos)
  return self.flagIndex[pos.x .. ',' .. pos.y .. ',' .. pos.z]
end

-- markers shipped with the client (data/minimap_markers.lua) are shown as temporary flags, so they are never saved.
-- They are kept apart from self.flags: the marker list is indexed in a grid per floor over several frames, widgets
-- are only made for markers near the camera (a few per frame, nearest first) and are kept in a cache when they
-- leave the window or the floor changes. Leaving the window only detaches a widget from the minimap (so the
-- layout no longer moves it on every step) and coming back re-attaches it without creating anything.
local PRESET_WINDOW = 40        -- tiles on each side of the camera
local PRESET_REFRESH = 16       -- recheck the window once the camera moves this many tiles from the last center
local PRESET_CELL = 32          -- grid cell size used to find nearby markers quickly
local PRESET_INDEX_PER_FRAME = 1000
local PRESET_CREATE_PER_FRAME = 15

local function presetCellKey(x, y)
  return math.floor(x / PRESET_CELL) * 100000 + math.floor(y / PRESET_CELL)
end

function UIMinimap:setPresetFlags(markers)
  self:clearPresetFlags()
  self.presetMarkers = {}   -- [z][cellKey] = list of marker ids, filled in the background
  self.presetList = markers
  self.presetWidgets = {}   -- [id] = widget (attached or not), false after the player deleted it
  self.presetAttached = {}  -- [id] = widget currently shown on the minimap
  self.presetQueue = {}

  local index = 1
  local function step()
    self.presetIndexEvent = nil
    if self:isDestroyed() or self.presetList ~= markers then return end
    local last = math.min(index + PRESET_INDEX_PER_FRAME - 1, #markers)
    for id = index, last do
      local m = markers[id]
      local floor = self.presetMarkers[m[3]]
      if not floor then
        floor = {}
        self.presetMarkers[m[3]] = floor
      end
      local key = presetCellKey(m[1], m[2])
      local cell = floor[key]
      if not cell then
        cell = {}
        floor[key] = cell
      end
      cell[#cell + 1] = id
    end
    index = last + 1
    if index <= #markers then
      self.presetIndexEvent = addEvent(step)
    else
      self.presetReady = true
      self:updatePresetFlags(true)
    end
  end
  self.presetIndexEvent = addEvent(step)
end

function UIMinimap:createPresetFlag(id)
  local m = self.presetList[id]
  local flag = g_ui.createWidget('MinimapFlag')
  flag.pos = {x = m[1], y = m[2], z = m[3]}
  flag.icon = m[4]
  flag.description = m[5]
  flag.temporary = true
  flag:setIcon('/images/game/minimap/flag' .. m[4])
  flag:setTooltip(m[5])
  flag.onMouseRelease = function(widget, pos, button)
    if button == MouseRightButton then
      local menu = g_ui.createWidget('PopupMenu')
      menu:setGameMenu(true)
      menu:addOption(tr('Delete mark'), function() widget:destroy() end)
      menu:display(pos)
      return true
    end
    return false
  end
  flag.onDestroy = function()
    if self.presetWidgets and self.presetWidgets[id] == flag then
      self.presetWidgets[id] = false
      self.presetAttached[id] = nil
    end
  end
  self.presetWidgets[id] = flag
  return flag
end

function UIMinimap:attachPresetFlag(id, flag)
  if flag:getParent() ~= self then
    self:insertChild(1, flag)
  end
  self:centerInPosition(flag, flag.pos)
  self.presetAttached[id] = flag
end

function UIMinimap:processPresetQueue()
  self.presetCreateEvent = nil
  if self:isDestroyed() or not self.presetQueue then return end
  local layout = self:getLayout()
  layout:disableUpdates()
  local created = 0
  while created < PRESET_CREATE_PER_FRAME and #self.presetQueue > 0 do
    local id = table.remove(self.presetQueue, 1)
    if self.presetWidgets[id] == nil then
      self:attachPresetFlag(id, self:createPresetFlag(id))
      created = created + 1
    end
  end
  layout:enableUpdates()
  layout:update()
  if #self.presetQueue > 0 then
    self.presetCreateEvent = addEvent(function() self:processPresetQueue() end)
  end
end

function UIMinimap:updatePresetFlags(force)
  if not self.presetReady then return end
  local cam = self:getCameraPosition()
  if not cam then return end
  local center = self.presetCenter
  if not force and center and center.z == cam.z
     and math.abs(center.x - cam.x) < PRESET_REFRESH and math.abs(center.y - cam.y) < PRESET_REFRESH then
    return
  end
  self.presetCenter = {x = cam.x, y = cam.y, z = cam.z}

  -- markers in the window on the camera floor
  local wanted = {}
  local floor = self.presetMarkers[cam.z]
  if floor then
    local minX, maxX = cam.x - PRESET_WINDOW, cam.x + PRESET_WINDOW
    local minY, maxY = cam.y - PRESET_WINDOW, cam.y + PRESET_WINDOW
    for cx = math.floor(minX / PRESET_CELL), math.floor(maxX / PRESET_CELL) do
      for cy = math.floor(minY / PRESET_CELL), math.floor(maxY / PRESET_CELL) do
        local cell = floor[cx * 100000 + cy]
        if cell then
          for _,id in ipairs(cell) do
            local m = self.presetList[id]
            if m[1] >= minX and m[1] <= maxX and m[2] >= minY and m[2] <= maxY then
              wanted[id] = true
            end
          end
        end
      end
    end
  end

  -- one layout pass for all the changes: every widget change would otherwise re-anchor all the others
  local layout = self:getLayout()
  layout:disableUpdates()
  for id,flag in pairs(self.presetAttached) do
    if not wanted[id] then
      self.presetAttached[id] = nil
      if not flag:isDestroyed() and flag:getParent() == self then
        self:removeChild(flag)
      end
    end
  end
  local queue = {}
  for id in pairs(wanted) do
    local m = self.presetList[id]
    -- a flag the player (or the server) put on the same tile wins
    if not self.presetAttached[id] and not self:getFlag({x = m[1], y = m[2], z = m[3]}) then
      local flag = self.presetWidgets[id]
      if flag then
        self:attachPresetFlag(id, flag)
      elseif flag == nil then
        table.insert(queue, id)
      end
    end
  end
  layout:enableUpdates()
  layout:update()

  -- new widgets are made a few per frame, nearest to the camera first
  table.sort(queue, function(a, b)
    local ma, mb = self.presetList[a], self.presetList[b]
    return math.max(math.abs(ma[1] - cam.x), math.abs(ma[2] - cam.y)) < math.max(math.abs(mb[1] - cam.x), math.abs(mb[2] - cam.y))
  end)
  self.presetQueue = queue
  if #queue > 0 and not self.presetCreateEvent then
    self.presetCreateEvent = addEvent(function() self:processPresetQueue() end)
  end
end

function UIMinimap:clearPresetFlags()
  removeEvent(self.presetIndexEvent)
  removeEvent(self.presetCreateEvent)
  self.presetIndexEvent = nil
  self.presetCreateEvent = nil
  local widgets = self.presetWidgets
  self.presetWidgets = nil
  if widgets then
    local layout = self:getLayout()
    if layout then layout:disableUpdates() end
    for _,flag in pairs(widgets) do
      if flag and not flag:isDestroyed() then flag:destroy() end
    end
    if layout then
      layout:enableUpdates()
      layout:update()
    end
  end
  self.presetAttached = nil
  self.presetQueue = nil
  self.presetCenter = nil
  self.presetReady = nil
  self.presetList = nil
  self.presetMarkers = nil
end

function UIMinimap:removeFlag(pos, icon, description)
  local flag = self:getFlag(pos)
  if flag then
    flag:destroy()
  end
end

function UIMinimap:reset()
  self:setZoom(0)
  if self.cross and self.cross.pos then
    self:setCameraPosition(self.cross.pos)
  end
end

function UIMinimap:move(x, y)
  local cameraPos = self:getCameraPosition()
  local scale = self:getScale()
  if scale > 1 then scale = 1 end
  local dx = x/scale
  local dy = y/scale
  local pos = {x = cameraPos.x - dx, y = cameraPos.y - dy, z = cameraPos.z}
  self:setCameraPosition(pos)
end

function UIMinimap:onMouseWheel(mousePos, direction)
  local keyboardModifiers = g_keyboard.getModifiers()
  if direction == MouseWheelUp and keyboardModifiers == KeyboardNoModifier then
    self:zoomIn()
  elseif direction == MouseWheelDown and keyboardModifiers == KeyboardNoModifier then
    self:zoomOut()
  elseif direction == MouseWheelDown and keyboardModifiers == KeyboardCtrlModifier then
    self:floorUp(1)
  elseif direction == MouseWheelUp and keyboardModifiers == KeyboardCtrlModifier then
    self:floorDown(1)
  end
end

function UIMinimap:onMousePress(pos, button)
  if not self:isDragging() then
    self.allowNextRelease = true
  end
end

function UIMinimap:onMouseRelease(pos, button)
  if not self.allowNextRelease then return true end
  self.allowNextRelease = false

  local mapPos = self:getTilePosition(pos)
  if not mapPos then return end

  if button == MouseLeftButton then
    local player = g_game.getLocalPlayer()
    if self.autowalk and player then
      player:autoWalk(mapPos)
    end
    return true
  elseif button == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Create mark'), function() self:createFlagWindow(mapPos) end)
    if self.onTogglePresetFlags then
      local text = self.presetMarkers and tr('Hide Tibia map markers') or tr('Show Tibia map markers')
      menu:addOption(text, function() self.onTogglePresetFlags(not self.presetMarkers) end)
    end
    menu:display(pos)
    return true
  end
  return false
end

function UIMinimap:onDragEnter(pos)
  self.dragReference = pos
  self.dragCameraReference = self:getCameraPosition()
  return true
end

function UIMinimap:onDragMove(pos, moved)
  local scale = self:getScale()
  local dx = (self.dragReference.x - pos.x)/scale
  local dy = (self.dragReference.y - pos.y)/scale
  local pos = {x = self.dragCameraReference.x + dx, y = self.dragCameraReference.y + dy, z = self.dragCameraReference.z}
  self:setCameraPosition(pos)
  return true
end

function UIMinimap:onDragLeave(widget, pos)
  return true
end

function UIMinimap:onStyleApply(styleName, styleNode)
  for name,value in pairs(styleNode) do
    if name == 'autowalk' then
      self.autowalk = value
    end
  end
end

function UIMinimap:createFlagWindow(pos)
  if self.flagWindow then return end
  if not pos then return end

  self.flagWindow = g_ui.createWidget('MinimapFlagWindow', rootWidget)

  local positionLabel = self.flagWindow:getChildById('position')
  local description = self.flagWindow:getChildById('description')
  local okButton = self.flagWindow:getChildById('okButton')
  local cancelButton = self.flagWindow:getChildById('cancelButton')

  positionLabel:setText(string.format('%i, %i, %i', pos.x, pos.y, pos.z))

  local flagRadioGroup = UIRadioGroup.create()
  for i=0,19 do
    local checkbox = self.flagWindow:getChildById('flag' .. i)
    checkbox.icon = i
    flagRadioGroup:addWidget(checkbox)
  end

  flagRadioGroup:selectWidget(flagRadioGroup:getFirstWidget())

  local successFunc = function()
    self:addFlag(pos, flagRadioGroup:getSelectedWidget().icon, description:getText())
    self:destroyFlagWindow()
  end

  local cancelFunc = function()
    self:destroyFlagWindow()
  end

  okButton.onClick = successFunc
  cancelButton.onClick = cancelFunc

  self.flagWindow.onEnter = successFunc
  self.flagWindow.onEscape = cancelFunc

  self.flagWindow.onDestroy = function() flagRadioGroup:destroy() end
end

function UIMinimap:destroyFlagWindow()
  if self.flagWindow then
    self.flagWindow:destroy()
    self.flagWindow = nil
  end
end
