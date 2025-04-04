local component = require("lib.gui.badr")
local icon      = require("lib.gui.icon")
local theme     = require("helpers.config").theme

local function label(props)
  local _font = props.font or love.graphics.getFont()
  local color = props.color or theme:read_color("label", "LABEL_TEXT")
  local iconSize = 20
  local padding = props.iconPadding or 4

  local textWidth = _font:getWidth(props.text or props)
  local textHeight = _font:getHeight()
  local totalWidth = textWidth
  if props.iconName then
    totalWidth = totalWidth + iconSize + padding
  end

  return component {
    text = props.text or props,
    visible = props.visible,
    id = props.id,
    x = props.x or 0,
    y = props.y or 0,
    width = totalWidth,
    height = textHeight,
    font = _font,
    icon = props.icon,
    draw = function(self)
      if not self.visible then return end

      love.graphics.push()
      love.graphics.setFont(self.font)

      -- Draw the icon on the left if icon is provided
      if self.icon then
        local leftIcon = icon {
          name = self.icon,
          x = self.x,
          y = self.y + (self.height - iconSize) / 2,
          size = iconSize
        }
        leftIcon:draw()
      end

      -- Calculate the position of the text based on the presence of an icon
      local textX = self.x
      if self.icon then
        textX = textX + iconSize + padding
      end

      -- Draw the label text
      love.graphics.setColor(color)
      love.graphics.print(self.text or "", textX, self.y)
      love.graphics.setColor({ 1, 1, 1 }) -- Reset color to white
      love.graphics.pop()
    end,
  }
end

return label
