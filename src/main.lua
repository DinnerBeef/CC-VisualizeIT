require "api/gaz"
require "api/screens"
require "api/weather"
require "api/text"
require "api/telem_custom"

shell.run('settings')

local telem = require 'telem'

local monitor = peripheral.wrap('back')
resetMonitor(monitor)


local backplane = telem.backplane()
    :addInput('tank_lava', telem.input.custom(inputMekanismDynamicTankAdapter("dynamicValve_0")))
    :addInput('tank_xp', telem.input.custom(inputMekanismDynamicTankAdapter("dynamicValve_1")))

    :addOutput('main_monitor', telem.output.custom(outputTankAdapter(tankScreen(2, monitor, true, 71))))

parallel.waitForAny(
  checkWeather,
  backplane:cycleEvery(0.1)
)
