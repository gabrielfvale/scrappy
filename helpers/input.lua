local input = {}

local joystick
local state = {
  last_event = nil,
  current_event = nil,
  trigger = false,
}

input.events = {
  LEFT = "left",
  RIGHT = "right",
  UP = "up",
  DOWN = "down",
  ESC = "escape",
  RETURN = "return",
  MENU = "lalt",
  PREV = "[",
  NEXT = "]",
}

input.joystick_mapping = {
  ["dpleft"] = input.events.LEFT,
  ["dpright"] = input.events.RIGHT,
  ["dpup"] = input.events.UP,
  ["dpdown"] = input.events.DOWN,
  ["a"] = input.events.RETURN,
  ["b"] = input.events.ESC,
  ["back"] = input.events.MENU,
  ["leftshoulder"] = input.events.PREV,
  ["rightshoulder"] = input.events.NEXT,
}

local cooldown_duration = 0.2
local last_trigger_time = -cooldown_duration

local function can_trigger_global(dt)
  local current_time = love.timer.getTime()
  if current_time - last_trigger_time >= cooldown_duration then
    last_trigger_time = current_time
    return true
  end
  return false
end

local function trigger(event)
  if can_trigger_global() then
    state.last_event = state.current_event
    state.current_event = event
    state.trigger = true
    -- print("Triggered: " .. event)  -- Debug
  end
end

function input.load()
  -- Initialize joystick
  local joysticks = love.joystick.getJoysticks()
  if #joysticks > 0 then
    joystick = joysticks[1]
  end
end

function input.update(dt)
  if joystick then
    for button, event in pairs(input.joystick_mapping) do
      if joystick:isGamepadDown(button) then
        trigger(event)
      end
    end
  end
end

function input.onEvent(callback)
  if state.trigger then
    state.trigger = false
    callback(state.current_event)
  end
end

function love.keypressed(key)
  for _, k in pairs(input.events) do
    if key == k then
      trigger(key)
    end
  end
end

return input
