CRSF_PAYLOAD = {
  1,    -- Message type (1 = system state)
  0,    -- Wifi
  0,    -- Armed
  0,    -- Control Source
  -1,    -- Status
  0x00, 0x00, -- Speed Limit
  0x00, 0x00, -- Current Limit
  0,    -- Torque Limit
}

CHANNEL_CONTROL_SOURCE = 'ch6'
CHANNEL_ARMED = 'ch5'
CHANNEL_WIFI = 'ch7'

-- CRSF_PAYLOAD = {
--   1,    -- Message type (1 = system state)
--   1,    -- Wifi
--   1,    -- Armed
--   3,    -- Control Source
--   1,    -- Status
--   0x28, 0x01 -- Speed Limit
--   0xFA, 0x00 -- Current Limit
--   65,    -- Torque Limit
-- }

local function getControlSourceIndex()
  local value = getValue(CHANNEL_CONTROL_SOURCE)
  if value < 0 then return 0 end
  if value == 0 then return 1 end
  return 2
end

-- Function to handle the source value logic based on a channel value
local function getControlSourceString()
  local index = getControlSourceIndex()
  if index == 0 then return "MANUAL" end
  if index == 1 then return "ONBCOM" end
  return "FL_CON"
end


local function crossfirePop()
  local command, data = crossfireTelemetryPop() -- 从遥测系统弹出命令和数据
  if command == 0x7F and data ~= nil then
    CRSF_PAYLOAD = data
  end
end

local function drawBoxWithText(x, y, width, height, textColor, backgroundColor, text)
  local font = textColor + MIDSIZE
  local textWidth, textHeight = lcd.sizeText(text, font)

  local textX = x + (width - textWidth) / 2
  local textY = y + (height - textHeight) / 2

  lcd.drawFilledRectangle(x, y, width, height, backgroundColor)
  lcd.drawText(textX, textY, text, font)
end

local function drawRow1Box(x, text, textColor, backgroundColor)
  local width, height, y = 130, 34, 0
  drawBoxWithText(x, y, width, height, textColor, backgroundColor, text)
end

local function drawProgressBar(x, y, w, h, value, max_value, fillColor)
  lcd.drawGauge(x, y, w, h, value, max_value, fillColor)
end

local function drawProgressBarWithText(x, y, value, max_value, text)
  local height    = 34
  local textColor = BLACK + MIDSIZE
  local textWidth = 150
  local barWidth  = 480 - textWidth
  lcd.drawText(x + 4, y + 2, text, textColor)
  drawProgressBar(x + textWidth + 10, y + 4, barWidth - 20, height - 8, value, max_value, BLACK)
end

local function statusToString(status)
  if status == 0 then return "ALL SYSTEMS GO" end
  if status == 1 then return "LOW BATTERY" end
  if status == 2 then return "NO TX SIGNAL" end
  if status == 3 then return "MOTOR ERROR" end
  if status == 4 then return "DISARMED" end
  return "DISCONNECTED"
end

-- Function to create the widget
local function create(zone, options)
  local wgt = {
    zone = zone,
    options = options
  }
  return wgt
end

-- Function to update the widget (if options are changed)
local function update(wgt, options)
  wgt.options = options
end

-- Background processing function (empty if not needed)
local function background(wgt)
end

-- Function to refresh the widget and display telemetry data
local function refresh(wgt)
  crossfirePop()
  local zone = wgt.zone
  local x, y = zone.x, zone.y
  local w, h = zone.w, zone.h -- 480x272
  local textColor = BLACK
  -- local lineHeight = 22 + 7 -- Adjusted for spacing
  local lineHeight = 34
  local labelWidth = 120 -- Adjusted for MIDSIZE text

  -- Telemetry data display
  -- Assume getValue returns telemetry values between 0-100 for percentages, actual values for others
  local telemetryData = {
    rssi = getValue('1RSS'),
    link = getValue('RQly'),
    fuel = getValue('Bat%'),
    curr = getValue('Curr'),
    volt = getValue('RxBt'),
    armed = getValue(CHANNEL_ARMED),
    trueArmed = CRSF_PAYLOAD[3] == 1,
    batt = getValue('tx-voltage'),
    wifi = getValue(CHANNEL_WIFI) > 0,
    trueWifi = CRSF_PAYLOAD[2] == 1,
    bat1 = getValue('Capa'),
    trueControlSource = CRSF_PAYLOAD[4],
    statusInt = CRSF_PAYLOAD[5],
    -- little endian
    speedLimit = (CRSF_PAYLOAD[7] * 256 + CRSF_PAYLOAD[6]) / 10,
    currentLimit = (CRSF_PAYLOAD[9] * 256 + CRSF_PAYLOAD[8]) / 10,
    torqueLimit = (CRSF_PAYLOAD[10]) / 10,
  }


  local GREEN = lcd.RGB(0x4CAF50)
  local ORANGE = lcd.RGB(0xFF9800)
  local RED = lcd.RGB(0xF44336)

  -- Clear canvas
  lcd.drawFilledRectangle(x, y, w, h, WHITE)

  local row1BoxWidth = 130

  -- Draw source
  local sourceValue = getControlSourceString()
  -- 0, 1 or 2
  local sourceIndex = getControlSourceIndex()
  local sourceColor = (sourceIndex == telemetryData.trueControlSource) and GREEN or ORANGE
  drawRow1Box(row1BoxWidth * 0, sourceValue, WHITE, sourceColor)

  -- Draw armed/disarmed
  local armedBool = telemetryData.armed <= 0
  local armedColor = (armedBool == telemetryData.trueArmed) and (armedBool and GREEN or RED) or ORANGE
  local armedText = telemetryData.trueArmed and "ARMED" or "DISARMED"
  drawRow1Box(row1BoxWidth * 1, armedText, WHITE, armedColor)

  -- Draw wifi
  local wifiSwitch = telemetryData.wifi
  local wifiColor = (wifiSwitch == telemetryData.trueWifi) and (wifiSwitch and RED or GREEN) or ORANGE
  local wifiText = telemetryData.trueWifi and "WiFi ON" or "WiFi OFF"
  drawRow1Box(row1BoxWidth * 2, wifiText, WHITE, wifiColor)

  -- TODO is it possible to get the percentage directly?
  -- Try ('Batt' sensor?, nvm that's just voltage)
  -- TODO given that these ranges depend on the battery, we should also show the voltage.
  local fullVoltage = 8.3
  local emptyVoltage = 6.7
  local batteryPercent = 0
  if telemetryData.batt > emptyVoltage then
    batteryPercent = (telemetryData.batt - emptyVoltage) / (fullVoltage - emptyVoltage) * 100
  end
  -- Draw transmitter battery percentage
  drawBoxWithText(row1BoxWidth * 3, 0, 480 - (row1BoxWidth * 3), 34, BLACK, WHITE,
    "TX " .. string.format("%.1f", telemetryData.batt) .. "V")


  -- Row 2
  local voltageString = string.format("VOLTAGE %.1fV", telemetryData.volt)
  local currentString = string.format("CURRENT %.1fA", telemetryData.curr)
  -- local batteryCountString = "BATT #" .. 4
  local row2String = voltageString .. "  " .. currentString
  lcd.drawText(x + 4, y + lineHeight, row2String, textColor + MIDSIZE)

  -- Row 3 (battery)
  local battString = "BATT: " .. telemetryData.fuel .. "%"
  drawProgressBarWithText(x, y + 2 * lineHeight, telemetryData.fuel, 100, battString)

  -- Row 4 (System Status)
  local statusString = statusToString(telemetryData.statusInt)
  local statusColor = telemetryData.statusInt == 0 and GREEN or RED
  drawBoxWithText(x, y + 3 * lineHeight, w, lineHeight, WHITE, statusColor, statusString)

  -- Row 5 (RSSI)
  local rssiString = "RSSI: " .. telemetryData.rssi .. "dB"
  drawProgressBarWithText(x, y + 4 * lineHeight, 130 + telemetryData.rssi, 130, rssiString)

  -- Row 6 (Link Quality)
  local linkString = "LINK: " .. telemetryData.link .. "%"
  drawProgressBarWithText(x, y + 5 * lineHeight, telemetryData.link, 100, linkString)

  -- Row 7 (Limits)
  local speedLimitString = "SPEED " .. string.format("%.1f", telemetryData.speedLimit) .. "rad/s"
  local currentLimitString = "CURR " .. string.format("%.1f", telemetryData.currentLimit) .. "A"
  local torqueLimitString = "TOR " .. string.format("%.1f", telemetryData.torqueLimit) .. "Nm"
  local limitsString = speedLimitString .. " " .. currentLimitString .. " " .. torqueLimitString
  lcd.drawText(x + 4, y + 6 * lineHeight, limitsString, textColor + MIDSIZE)
  
  -- Row 8 (low & critical battery voltage)
  --   local lowVoltageString = string.format("%.1f", 17.5)
  --   local criticalVoltageString = string.format("%.1f", 16.5)
  --   local voltageThresholdsString = "LOW/EMPTY BATTERY VOLT " .. lowVoltageString .. "/" .. criticalVoltageString .. "V"
  --   lcd.drawText(x + 4, y + 7 * lineHeight, voltageThresholdsString, textColor + MIDSIZE)
end

-- Return the widget table containing all necessary widget functions
return {
  name = "Robot_1",
  options = {},
  create = create,
  update = update,
  background = background,
  refresh = refresh
}
