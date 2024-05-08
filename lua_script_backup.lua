-- Define a function to create a progress bar
LastData = { 0, 0, 0, 0 }


local function drawProgressBar(x, y, w, h, value, max_value, fillColor)
  local ratio = math.max(0, math.min(value / max_value, 1)) -- Ensure the ratio is between 0 and 1
  local bar_width = ratio * w
  lcd.drawRectangle(x, y, w, h, BLACK)
  lcd.drawFilledRectangle(x, y, bar_width, h, fillColor)
end

-- Function to handle the source value logic based on a channel value
local function getSourceValue(channel)
  local value = getValue(channel)
  if value < 0 then return "MANUAL" end
  if value == 0 then return "ONBCOM" end
  return "FL_CON"
end

local function crossfirePop()
  local command, data = crossfireTelemetryPop() -- 从遥测系统弹出命令和数据
  if command == 0x7F and data ~= nil then
    LastData = data
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

local function drawProgressBarWithText(x, y, value, max_value, text)
  local height = 34
  local textColor  = BLACK + MIDSIZE
  local textWidth = 150
  local barWidth = 480 - textWidth
  lcd.drawText(x + 4, y + 2, text, textColor)
  drawProgressBar(x + textWidth + 10, y + 4, barWidth - 20, height - 8, value, max_value, BLACK)
end

-- local function drawRow1Box(x, text, backgroundColor, textColor)
--   local width = 130
--   local height = 34
--   lcd.drawFilledRectangle(x, 0, width, height, backgroundColor)
--   lcd.drawText(x + 4, 2, text, textColor + MIDSIZE)
-- end

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
  local barHeight = 20
  -- local lineHeight = 22 + 7 -- Adjusted for spacing
  local lineHeight = 34
  local labelWidth = 120    -- Adjusted for MIDSIZE text
  local barWidth = zone.w - labelWidth - 70
  local barColor = BLACK

  -- Telemetry data display
  -- Assume getValue returns telemetry values between 0-100 for percentages, actual values for others
  local telemetryData = {
    rssi = getValue('RSS1'),
    link = getValue('RQly'),
    fuel = getValue('Bat%'),
    curr = getValue('Curr'),
    volt = getValue('VOLT'),
    rover = getValue('ch5'),
    batt = getValue('tx-voltage'),
    dashboard = getValue('ch7'),
    bat1 = getValue('Capa')
  }

  local GREEN = lcd.RGB(0x4CAF50)
  local RED = lcd.RGB(0xF44336)

  -- Clear canvas
  lcd.drawFilledRectangle(x, y, w, h, WHITE)
  
  local row1BoxWidth = 130

  -- Draw source
  local sourceValue = getSourceValue('ch6')
  drawRow1Box(row1BoxWidth * 0, sourceValue, BLACK, WHITE)

  -- Draw armed/disarmed
  local armedColor = telemetryData.rover <= 0 and RED or GREEN
  local armedText = telemetryData.rover <= 0 and "DISARMED" or "ARMED"
  drawRow1Box(row1BoxWidth * 1, armedText, WHITE, armedColor)
  
  -- Draw wifi
  -- Switch on + confirmed on = red
  -- switch on + confirmed off = orange
  -- switch off + * = green
  local telemWifiEnabled = false -- TODO (custom telemetry)
  local wifiSwitch = telemetryData.dashboard > 0
  local wifiColor = wifiSwitch and (telemWifiEnabled and RED or ORANGE) or GREEN
  drawRow1Box(row1BoxWidth * 2, "WiFi OFF", WHITE, wifiColor)

  -- TODO is it possible to get the percentage directly?
  local fullVoltage = 8.3
  local emptyVoltage = 6.7
  local batteryPercent = 0
  if telemetryData.batt > emptyVoltage then
    batteryPercent = (telemetryData.batt - emptyVoltage) / (fullVoltage - emptyVoltage) * 100
  end
  -- Draw transmitter battery percentage
  drawBoxWithText(row1BoxWidth * 3, 0, 480 - (row1BoxWidth * 3), 34, BLACK, WHITE,
  "TX " .. math.floor(batteryPercent) .. "%")
  

  -- Row 2
  local voltageString = string.format("VOLTAGE %.1f", telemetryData.volt)
  local currentString = string.format("CURRENT %.1f", telemetryData.curr)
  local batteryCountString = "BATT #" .. 4
  local row2String = voltageString .. "  " .. currentString .. "  " .. batteryCountString
  lcd.drawText(x + 4, y + lineHeight, row2String, textColor + MIDSIZE)

  -- Row 3 (battery) 
  local battString = "BATT: " .. telemetryData.fuel.. "%"
  drawProgressBarWithText(x, y + 2 * lineHeight, telemetryData.fuel, 100, battString)
  
  -- Row 4 (System Status)
  drawBoxWithText(x, y + 3 * lineHeight, w, lineHeight, WHITE, GREEN, "ALL SYSTEMS GO")
  
  -- Row 5 (RSSI)
  local rssiString = "RSSI: " .. telemetryData.rssi .. "dB"
  drawProgressBarWithText(x, y + 4 * lineHeight, -telemetryData.rssi, 130, rssiString)
  
  -- Row 6 (Link Quality)
  local linkString = "LINK: " .. telemetryData.link .. "%"
  drawProgressBarWithText(x, y + 5 * lineHeight, telemetryData.link, 100, linkString)
  
  -- Row 7 (Limits)
  local speedLimitString = "SPEED " .. 20 .. "rad/s"
  local currentLimitString = "CURR " .. string.format("%.1f", 4) .. "A"
  local torqueLimitString = "TORQUE " .. string.format("%.1f", 4) .. "Nm"
  local limitsString = speedLimitString .. " " .. currentLimitString .. " " .. torqueLimitString
  lcd.drawText(x + 4, y + 6 * lineHeight, limitsString, textColor + MIDSIZE)
  
  -- Row 8 (low & critical battery voltage)
  local lowVoltageString = string.format("%.1f", 17.5)
  local criticalVoltageString = string.format("%.1f", 16.5)
  local voltageThresholdsString = "LOW/EMPTY BATTERY VOLT " .. lowVoltageString .. "/" .. criticalVoltageString .. "V"
  lcd.drawText(x + 4, y + 7 * lineHeight, voltageThresholdsString, textColor + MIDSIZE)
  

  -- Draw transmitter battery percent

  -- Draw the source line
  -- lcd.drawText(x + 2, y, "SOURCE: " .. sourceValue, textColor + MIDSIZE)

  


  if LastData ~= nil then
    Frame_type = LastData[1] -- 假设第一个数据字节是帧类型
    L_tmp = LastData[2]     -- 左电机温度
    R_tmp = LastData[3]     -- 右电机温度
    --DREW TETS
    -- if not(L_tmp==nil&R_tmp==nil) then
    --     icd.drawText(x+10,y+10,"test:"..L_tmp.."°C",textColor+MIDSIZE)
    --   icd.drawText(x+20,y+20,"test:"..R_tmp.."°C",textColor+MIDSIZE)
  end


  -- Draw RSSI
  -- lcd.drawText(x + 2, y + lineHeight, "RSSI:" .. telemetryData.rssi .. "dB", textColor + MIDSIZE)
  -- drawProgressBar(x + labelWidth, y + lineHeight, barWidth, barHeight, telemetryData.rssi, 100, barColor)

  -- Draw LINK
  -- lcd.drawText(x + 2, y + 2 * lineHeight, "LINK:" .. telemetryData.link .. "%", textColor + MIDSIZE)
  -- drawProgressBar(x + labelWidth, y + 2 * lineHeight, barWidth, barHeight, telemetryData.link, 100, barColor)

  -- Draw ROVER ENABLED status
  -- local roverColor = telemetryData.rover <= 0 and GREEN or RED
  -- lcd.drawText(x + 2, y + 3 * lineHeight, "ROVER ENABLED:", textColor + MIDSIZE)
  -- lcd.drawFilledRectangle(x + labelWidth + 250, y + 3 * lineHeight, barHeight + 10, barHeight, roverColor)

  -- Draw DASHBOARD ENABLED status
  -- local dashboardColor = telemetryData.dashboard <= 0 and GREEN or RED
  -- lcd.drawText(x + 2, y + 4 * lineHeight, "DASHBOARD ENABLED:", textColor + MIDSIZE)
  -- lcd.drawFilledRectangle(x + labelWidth + 250, y + 4 * lineHeight, barHeight + 10, barHeight, dashboardColor)

  -- Draw FUEL
  -- lcd.drawText(x + 2, y + 5 * lineHeight, "Batt:" .. telemetryData.fuel .. "%", textColor + MIDSIZE)
  -- drawProgressBar(x + labelWidth, y + 5 * lineHeight, barWidth, barHeight, telemetryData.fuel, 100, barColor)

  -- Draw CURRENT
  -- lcd.drawText(x + 2, y + 6 * lineHeight, "CURRENT:" .. telemetryData.curr .. "A", textColor + MIDSIZE)
  --Drew BATT
  -- lcd.drawText(x + labelWidth + 60, y + 6 * lineHeight, "Bat:" .. telemetryData.bat1 .. "mAh", textColor + MIDSIZE)
  --lcd.drawText(x + 120, y + 6*lineHeight, "BATT " .. telemetryData.batt .. "A", textColor + MIDSIZE)
  -- Draw VOLTAGE
  -- lcd.drawText(x + labelWidth + 170, y + 6 * lineHeight, "VOLTAGE:" .. telemetryData.volt .. "V", textColor + MIDSIZE)


  -- local eng1Data = {
  --   tmp = getValue('1Tmp'),
  --   rpm = getValue('1Rpm'),
  --   per = getValue('1Per'),
  --   torque = getValue('1Tor')
  -- }

  -- local eng2Data = {
  --   tmp = getValue('2Tmp'),
  --   rpm = getValue('2Rpm'),
  --   per = getValue('2Per'),
  --   torque = getValue('2Tor')
  -- }

  -- -- Display the data for engine 1
  -- local eng1X = x + 2
  -- lcd.drawText(eng1X, y + 7*lineHeight, "L: " .. eng1Data.tmp .. "°C", textColor + MIDSIZE)
  -- eng1X = eng1X + 100
  -- lcd.drawText(eng1X, y + 7*lineHeight, eng1Data.rpm .. "RAD/s", textColor + MIDSIZE)
  -- eng1X = eng1X + 100
  -- lcd.drawText(eng1X, y + 7*lineHeight, eng1Data.per .. "°", textColor + MIDSIZE)
  -- eng1X = eng1X + 100
  -- lcd.drawText(eng1X, y + 7*lineHeight, eng1Data.torque .. "Nm", textColor + MIDSIZE)

  -- -- Display the data for engine 2
  -- local eng2X = x + 2
  -- lcd.drawText(eng2X, y + 8*lineHeight, "R: " .. eng2Data.tmp .. "°C", textColor + MIDSIZE)
  -- eng2X = eng2X + 100
  -- lcd.drawText(eng2X, y + 8*lineHeight, eng2Data.rpm .. "RAD/s", textColor + MIDSIZE)
  -- eng2X = eng2X + 100
  -- lcd.drawText(eng2X, y + 8*lineHeight, eng2Data.per .. "°", textColor + MIDSIZE)
  -- eng2X = eng2X + 100
  -- lcd.drawText(eng2X, y + 8*lineHeight, eng2Data.torque .. "Nm", textColor + MIDSIZE)
  -- lcd.drawText(x + 2, y + 7 * lineHeight, "COMMAND" .. LastCommand, textColor + MIDSIZE)
  -- lcd.drawText(x + 202, y + 7 * lineHeight, "TYPE" .. Frame_type, textColor + MIDSIZE)
  --lcd.drawText(x+202,y+7*lineHeight,"COMMAND"..LastCommand,textColor+MIDSIZE)

  -- lcd.drawText(x + 2, y + 8 * lineHeight, "[2]" .. L_tmp, textColor + MIDSIZE)
  -- lcd.drawText(x + 102, y + 8 * lineHeight, "[3]" .. R_tmp, textColor + MIDSIZE)
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
