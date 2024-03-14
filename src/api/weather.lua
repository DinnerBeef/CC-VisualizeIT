-- Function to fetch and parse JSON data
require "api/http"
require "api/text"
require "api/sound"
require "settings"

local monitor = peripheral.wrap('back')

local function getWindDirection(degrees)
  local cardinalDirections = { "North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest" }
  local index = math.floor(((degrees % 360) / 45) + 0.5) % 8 + 1
  return cardinalDirections[index]
end

local function convertToAMPM(timeString)
  -- Extract hour and minute using string manipulation
  local hour, minute = timeString:match("(%d+):(%d+)")
  hour = tonumber(hour)
  minute = tonumber(minute)

  local period = "AM"
  if hour >= 12 then
    period = "PM"
    hour = hour == 12 and 12 or hour - 12
  end

  return string.format("%02d:%02d %s", hour, minute, period)
end

function getCurrentWeather(latitude, longitude)
  local url = "https://api.open-meteo.com/v1/forecast?latitude=" ..
      latitude ..
      "&longitude=" ..
      longitude ..
      "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m&daily=sunrise,sunset&temperature_unit=fahrenheit&timezone=America%2FChicago&forecast_days=1&wind_speed_unit=mph"
  local jsonData = fetchJsonData(url)
  if jsonData then
    local windDirection = getWindDirection(jsonData.current.wind_direction_10m)
    return jsonData.current.temperature_2m, jsonData.current.relative_humidity_2m, jsonData.current.wind_speed_10m,
        windDirection, convertToAMPM(jsonData.daily.sunrise[1]), convertToAMPM(jsonData.daily.sunset[1])
  else
    return nil
  end
end

function getWarning(latitude, longitude)
  local url  = "https://weather.unreal.codes/v2/alerts/point/" .. latitude .. "/" .. longitude
  local data = fetchJsonData(url)
  if data then
    local warning = data.data.types.warning
    if warning then
      return checkWeatherOrder(warning)
    else
      return "None"
    end
  else
    return "Error fetching data"
  end
end

function getWatches(latitude, longitude)
  local url  = "https://weather.unreal.codes/v2/alerts/point/" .. latitude .. "/" .. longitude
  local data = fetchJsonData(url)
  if data then
    local watches = data.data.types.watch
    if watches then
      return checkWeatherOrder(watches)
    else
      return "None"
    end
  else
    return "Error fetching data"
  end
end

function checkWeatherOrder(types)
  local weatherTypes = {
    ["Tornado"] = "Tornado",
    ["SevereThunderstorm"] = "Severe Thunderstorm",
    ["Freeze"] = "Freeze",
    ["WindChill"] = "Wind Chill",
    ["WinterStorm"] = "Winter Storm",
    ["Flood"] = "Flood",
    ["ExcessiveHeat"] = "Excessive Heat",
    ["FlashFlood"] = "Flash Flood",
    ["HighWind"] = "High Wind",
    ["Wind"] = "Wind",
    ["Blizzard"] = "Blizzard",
    ["FireWeather"] = "Fire Weather"
  }

  for warringNumber, warningType in pairs(types) do
    if weatherTypes[warningType] then
      return weatherTypes[warningType]
    end
  end
end

function checkWeather()
  local weatherWindow = window.create(monitor, 1, 1, monitor.getSize(), 5)
  weatherWindow.setBackgroundColor(colors.black)
  weatherWindow.clear()
  weatherWindow.setCursorPos(1, 1)
  weatherWindow.setTextColor(colors.magenta)
  centerText(weatherWindow, "Current Weather", 1)
  local playMessage = false
  local long, lat = settting_Latitude, settting_Longitude
  while true do
    local temp, humidity, windSpeed, windDirection, sunrise, sunset = getCurrentWeather(long, lat)
    local temperature = {
      { "Temperature: ",    colors.yellow },
      { tostring(temp),     colors.green },
      { "F",                colors.green },
      { "  ",               colors.black },
      { "Humidity: ",       colors.yellow },
      { tostring(humidity), colors.green },
      { "%",                colors.green }
    }
    local wind = {
      { "Wind: ",            colors.yellow },
      { tostring(windSpeed), colors.green },
      { " mph ",             colors.green },
      { "from the ",         colors.yellow },
      { windDirection,       colors.green }
    }
    local sunriseSunset = {
      { "Sunrise: ", colors.yellow },
      { sunrise,     colors.green },
      { "  ",        colors.black },
      { "Sunset: ",  colors.yellow },
      { sunset,      colors.green }
    }
    local warnings = getWarning(long, lat);
    local watches = getWatches(long, lat);
    local warningWatches = {
      { "Warnings: ", colors.yellow },
      { warnings,     colors.red },
      { "  ",         colors.black },
      { "Watches: ",  colors.yellow },
      { watches,      colors.red }
    }
    if not playMessage then
      if warnings == "Severe Thunderstorm" then
        playSoundAllSpeakers("weather/warnings/storm")
        playMessage = true
      end
    elseif warnings == "None" then
      playMessage = false
    end
    -- This Is A Top Level Alert And Will Always Play
    if warnings == "Tornado" then
      playSoundAllSpeakers("weather/warnings/tornado")
    end
    printStyledTextCentered(weatherWindow, temperature, 2)
    printStyledTextCentered(weatherWindow, wind, 3)
    printStyledTextCentered(weatherWindow, sunriseSunset, 4)
    printStyledTextCentered(weatherWindow, warningWatches, 5)
    sleep(60)
  end
end
