local monBG = colors.gray
local winBG = colors.black

function tableLength(T)
  local count = 0
  for _, v in pairs(T) do
    count = count + v["amount"]
  end
  return count
end

function getTopStored(T)
  length = tableLength(T)
  if length > 0 then
    table.sort(T, function(a, b)
      return a.amount > b.amount
    end)
    return T[1].displayName
  end
  return "null"
end

function format_int(number)
  local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
  -- reverse the int-string and append a comma to all blocks of 3 digits
  int = int:reverse():gsub("(%d%d%d)", "%1,")
  -- reverse the int-string back remove an optional comma and put the
  -- optional minus and fractional part back
  return minus .. int:reverse():gsub("^,", "") .. fraction
end

function shortenNum(n)
  if n >= 10 ^ 9 then
    return string.format("%.2fG", n / 10 ^ 9)
  elseif n >= 10 ^ 6 then
    return string.format("%.2fM", n / 10 ^ 6)
  elseif n >= 10 ^ 3 then
    return string.format("%.2fK", n / 10 ^ 3)
  else
    return tostring(n)
  end
end

function roundNum(val, decimal)
  if (decimal) then
    return math.floor(((val * 10 ^ decimal) + 0.5) / (10 ^ decimal))
  else
    return math.floor(val + 0.5)
  end
end

function drawPixel(window, x, y, color)
  window.setCursorPos(x, y)
  window.setBackgroundColor(color)
  window.write(" ")
end

function drawProgressBar(window, x, y, value, barColour, borderColour)
  winX, winY = window.getSize()
  if barColour == nil then
    barColour = colors.red
  end
  if borderColour == nil then
    borderColour = colors.white
  end

  for i = 0, value do
    drawPixel(window, x + 1 + i, y + 3, barColour)
  end
  drawPixel(window, x, y + 3, borderColour)
  drawPixel(window, winX, y + 3, borderColour)

  for i = 0, winX - 1 do
    drawPixel(window, x + i, y + 2, borderColour)
    drawPixel(window, x + i, y + 4, borderColour)
  end
end

function centerText(window, text, yPos)
  local x, y = window.getSize()
  window.setCursorPos(math.ceil((x / 2) - (text:len() / 2)), yPos)
  window.write(text)
end

local function getLevelFromXP(xp)
  if xp < 0 then
    return 0 -- Assuming level 0 for negative XP
  elseif xp <= 352 then
    -- Solve for level when xp is between 0 and 352
    return math.floor((-3 + math.sqrt(9 + 4 * xp)) / 2)
  elseif xp <= 1507 then
    -- Solve for level when xp is between 353 and 1507
    return math.floor((40.5 + math.sqrt(1640.25 + 10 * xp)) / 5)
  else
    -- Solve for level when xp is greater than 1507
    return math.floor((162.5 + math.sqrt(26569.25 + 18 * xp)) / 9)
  end
end

function drawTank(window, tankName, x, y, color, maxLiq, currentLiq)
  window.setBackgroundColor(winBG)
  window.clear()
  if currentLiq == nil then
    currentLiq = 0
  end

  if maxLiq == nil then
    maxLiq = 0
  end

  local percentage = roundNum(((currentLiq / maxLiq) * 100), 0)

  for i = 0, 9 do
    drawPixel(window, x, y + i, colors.white)
    drawPixel(window, x + 14, y + i, colors.white)
  end

  for i = 1, 13 do
    drawPixel(window, x + i, y + 9, colors.white)
  end

  local rows = roundNum((percentage / 13), 0)
  if percentage ~= 0 then
    for i = 8 - rows, 8 do
      for j = 1, 13 do
        if tankName == "lava" then
          if math.random(1, 20 - i) == 1 then
            if math.random(1, 4) == 1 then
              drawPixel(window, x + j, y + i, colors.black)
            else
              drawPixel(window, x + j, y + i, colors.orange)
            end
          else
            drawPixel(window, x + j, y + i, colors.red)
          end
        elseif tankName == "mob_grinding_utils:fluid_xp" then
          drawPixel(window, x + j, y + i, colors.lime)
        else
          drawPixel(window, x + j, y + i, colors.green)
        end
      end
    end
  end

  if tankName == "mob_grinding_utils:fluid_xp" then
    tankName = "Liquid XP"
    window.setCursorPos(x, y + 10)
    window.setBackgroundColor(monBG)
    window.clearLine()
    window.setCursorPos(x, y + 11)
    window.clearLine()
    window.setTextColor(colors.white)
    window.write(tankName .. " " .. tostring(percentage) .. "%")
    window.setCursorPos(x, y + 12)
    window.clearLine()
    window.write(tostring(getLevelFromXP((currentLiq * 1000) / 20)) .. " Levels")
  else
    window.setCursorPos(x, y + 10)
    window.setBackgroundColor(monBG)
    window.clearLine()
    window.setCursorPos(x, y + 11)
    window.clearLine()
    window.setTextColor(colors.white)
    window.write(tankName .. " " .. tostring(percentage) .. "%")
    window.setCursorPos(x, y + 12)
    window.clearLine()
    window.write(tostring(shortenNum(currentLiq)) .. "/" .. tostring(shortenNum(maxLiq)) .. "")
  end
end

function drawEnergy(window, name, unit, x, y, energyMax, energyCurrent, energyUsage)
  winX, winY = window.getSize()
  window.setBackgroundColor(winBG)
  window.clear()
  energyPercent = roundNum(((energyCurrent / energyMax) * 100), 0)

  energyCols = roundNum((energyPercent * (winX - 3) / 100), 0)

  drawProgressBar(window, x, y, energyCols)

  -- drawPixel(window, x, y + 3, colors.white)
  -- drawPixel(window, x + 27, y + 3, colors.white)

  -- for i = 0, 27 do
  --     drawPixel(window, x + i, y + 2, colors.white)
  --     drawPixel(window, x + i, y + 4, colors.white)
  -- end

  -- for i = 0, energyCols do
  --     drawPixel(window, x + 1 + i, y + 3, colors.red)
  -- end

  local energryString = ""
  if energyUsage ~= nil then
    energryString = tostring(shortenNum(roundNum(energyCurrent))) ..
        unit .. "/" .. tostring(shortenNum(roundNum(energyMax))) .. unit .. "|" .. tostring(shortenNum(energyUsage))
  else
    energryString = tostring(shortenNum(roundNum(energyCurrent))) ..
        unit .. "/" .. tostring(shortenNum(roundNum(energyMax))) .. unit
  end

  window.setCursorPos(x, y)
  window.setBackgroundColor(monBG)
  window.clearLine()
  window.setTextColor(colors.white)
  window.write(name .. " " .. energyPercent .. "%")
  window.setCursorPos(x, y + 1)
  window.clearLine()
  window.write(energryString)
  window.setBackgroundColor(winBG)
end
