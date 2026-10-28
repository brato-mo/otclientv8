-- @docclass
g_effects = {}

function g_effects.fadeIn(widget, time, elapsed)
  if not widget or widget:isDestroyed() then return end
  if not elapsed then elapsed = 0 end
  if not time then time = 300 end
  widget:setOpacity(math.min(elapsed/time, 1))
  removeEvent(widget.fadeEvent)
  if elapsed < time then
    removeEvent(widget.fadeEvent)
    widget.fadeEvent = scheduleEvent(function()
      g_effects.fadeIn(widget, time, elapsed + 30)
    end, 30)
  else
    widget.fadeEvent = nil
  end
end

function g_effects.fadeOut(widget, time, elapsed)
  if not widget or widget:isDestroyed() then return end
  if not elapsed then elapsed = 0 end
  if not time then time = 300 end
  elapsed = math.max((1 - widget:getOpacity()) * time, elapsed)
  removeEvent(widget.fadeEvent)
  widget:setOpacity(math.max((time - elapsed)/time, 0))
  if elapsed < time then
    widget.fadeEvent = scheduleEvent(function()
      g_effects.fadeOut(widget, time, elapsed + 30)
    end, 30)
  else
    widget.fadeEvent = nil
  end
end

function g_effects.cancelFade(widget)
  removeEvent(widget.fadeEvent)
  widget.fadeEvent = nil
end

function g_effects.startBlink(widget, duration, interval, clickCancel)
  duration = duration or 0 -- until stop is called
  interval = interval or 500
  if clickCancel == nil then clickCancel = true end

  removeEvent(widget.blinkEvent)
  removeEvent(widget.blinkStopEvent)

  widget.blinkEvent = cycleEvent(function()
    widget:setOn(not widget:isOn())
  end, interval)

  if duration > 0 then
    widget.blinkStopEvent = scheduleEvent(function()
      g_effects.stopBlink(widget)
    end, duration)
  end

  disconnect(widget, { onClick = g_effects.stopBlink })
  if clickCancel then
    connect(widget, { onClick = g_effects.stopBlink })
  end
end

function g_effects.stopBlink(widget)
  disconnect(widget, { onClick = g_effects.stopBlink })
  removeEvent(widget.blinkEvent)
  removeEvent(widget.blinkStopEvent)
  widget.blinkEvent = nil
  widget.blinkStopEvent = nil
  if widget:isDestroyed() then return end
  widget:setOn(false)
end
