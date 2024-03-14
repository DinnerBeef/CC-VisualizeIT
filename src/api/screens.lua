function tankScreen(tanks, monitor, center, maxWinWidth)
  if maxWinWidth == nil then
    maxWinWidth = monitor.getSize()
  end

  local windowWidth = (tanks * 15) + (tanks * 3) - 3
  if windowWidth > maxWinWidth then
    error("The number of tanks exceeds the maximum window width")
  end

  local xPos
  if center then
    xPos = (maxWinWidth / 2) - (7 * tanks)
  else
    xPos = 2 -- Default position if not centered
  end
  local win = window.create(monitor, xPos, 7, windowWidth, 13)
  return win
end

function resetMonitor(monitor)
  monitor.setTextScale(1)
  monitor.clear()
  monitor.setBackgroundColor(colors.black)
end
