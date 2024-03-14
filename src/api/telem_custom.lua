local telem = require 'telem'

outputTankAdapter = function(tankWindow)
  return function(collection)
    local data = {}

    for _, metric in pairs(collection.metrics) do
      if string.find(metric.source, "dynamicValve") then
        table.insert(data,
          { name = simpleName(metric.name), fluidAmount = metric.value, fluidCapacity = tonumber(metric.unit) })
      else
        if (string.find(metric.source, "ae2:sky_tank")) then
          table.insert(data, { name = simpleName(metric.name), fluidAmount = metric.value, fluidCapacity = 16 })
        end
      end
    end

    local tankWindowSize = tankWindow.getSize()
    local count = 0
    for _, fluid in pairs(data) do
      if (tankWindowSize < 15) then
        return
      end
      if (count == 0) then
        drawTank(window.create(tankWindow, 1, 1, 15, 13), fluid.name, 1, 1, colors.red, fluid.fluidCapacity,
          fluid.fluidAmount)
        tankWindowSize = tankWindowSize - 15
      else
        drawTank(window.create(tankWindow, (count * 15) + 1 + (count * 3), 1, 15, 13), fluid.name, 1, 1,
          colors.green, fluid.fluidCapacity, fluid.fluidAmount)
        tankWindowSize = tankWindowSize - 18
      end
      count = count + 1
    end
  end
end

inputMekanismDynamicTankAdapter = function(source)
  return function()
    local dynamicTank = peripheral.wrap(source)
    local stored = dynamicTank.getStored()

    return
        telem.metric { name = 'storage:' .. stored.name, value = stored.amount / 1000, unit = tostring(dynamicTank.getTankCapacity() / 1000), source = source }
  end
end
