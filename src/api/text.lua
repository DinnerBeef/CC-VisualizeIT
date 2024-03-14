function printStyledTextCentered(window, textTable, yPos)
  local x, _ = window.getSize()
  local totalWidth = 0
  -- Calculate the total width of the text
  for _, item in ipairs(textTable) do
    local text = item[1] or ""
    totalWidth = totalWidth + #text
  end
  local startX = math.ceil((x - totalWidth) / 2)
  local currentX = startX

  for _, item in ipairs(textTable) do
    local text = item[1] or ""
    local color = item[2] or colors.white -- Default color to white if not specified
    window.setTextColor(color)
    window.setCursorPos(currentX, yPos)
    window.write(text)
    currentX = currentX + #text
  end
  -- Reset text color after printing
  window.setTextColor(colors.white)
end

simpleName = function(name)
  return name:match(".*:(.*)")
end
