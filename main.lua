-- Define a function to create a progress bar
LastData = { 0, 0, 0, 0 }


local function drawProgressBar(x, y, w, h, value, max_value, BLACK, fillColor)
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
  local zone = wgt.zone
  local x, y = zone.x, zone.y
  local w, h = zone.w, zone.h
  local textColor = BLACK
  local barHeight = 20
  local lineHeight = 22 + 7 -- Adjusted for spacing
  local labelWidth = 120    -- Adjusted for MIDSIZE text
  local barWidth = zone.w - labelWidth - 70
  local barColor = BLACK

  -- Clear canvas
  lcd.drawFilledRectangle(x, y, w, h, WHITE)

  -- Draw the source line
  local sourceValue = getSourceValue('ch6')
  lcd.drawText(x + 2, y, "SOURCE: " .. sourceValue, textColor + MIDSIZE)

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


  crossfirePop()
  if LastCommand ~= nil and LastData ~= nil then
    Frame_type = LastData[1] -- 假设第一个数据字节是帧类型
    L_tmp = LastData[2]     -- 左电机温度
    R_tmp = LastData[3]     -- 右电机温度
    --DREW TETS
    -- if not(L_tmp==nil&R_tmp==nil) then
    --     icd.drawText(x+10,y+10,"test:"..L_tmp.."°C",textColor+MIDSIZE)
    --   icd.drawText(x+20,y+20,"test:"..R_tmp.."°C",textColor+MIDSIZE)
  end


  -- Draw RSSI
  lcd.drawText(x + 2, y + lineHeight, "RSSI:" .. telemetryData.rssi .. "dB", textColor + MIDSIZE)
  drawProgressBar(x + labelWidth, y + lineHeight, barWidth, barHeight, telemetryData.rssi, 100, barColor)

  -- Draw LINK
  lcd.drawText(x + 2, y + 2 * lineHeight, "LINK:" .. telemetryData.link .. "%", textColor + MIDSIZE)
  drawProgressBar(x + labelWidth, y + 2 * lineHeight, barWidth, barHeight, telemetryData.link, 100, barColor)

  -- Draw ROVER ENABLED status
  local roverColor = telemetryData.rover <= 0 and GREEN or RED
  lcd.drawText(x + 2, y + 3 * lineHeight, "ROVER ENABLED:", textColor + MIDSIZE)
  lcd.drawFilledRectangle(x + labelWidth + 250, y + 3 * lineHeight, barHeight + 10, barHeight, roverColor)

  -- Draw DASHBOARD ENABLED status
  local dashboardColor = telemetryData.dashboard <= 0 and GREEN or RED
  lcd.drawText(x + 2, y + 4 * lineHeight, "DASHBOARD ENABLED:", textColor + MIDSIZE)
  lcd.drawFilledRectangle(x + labelWidth + 250, y + 4 * lineHeight, barHeight + 10, barHeight, dashboardColor)

  -- Draw FUEL
  lcd.drawText(x + 2, y + 5 * lineHeight, "Batt:" .. telemetryData.fuel .. "%", textColor + MIDSIZE)
  drawProgressBar(x + labelWidth, y + 5 * lineHeight, barWidth, barHeight, telemetryData.fuel, 100, barColor)

  -- Draw CURRENT
  lcd.drawText(x + 2, y + 6 * lineHeight, "CURRENT:" .. telemetryData.curr .. "A", textColor + MIDSIZE)
  --Drew BATT
  lcd.drawText(x + labelWidth + 60, y + 6 * lineHeight, "Bat:" .. telemetryData.bat1 .. "mAh", textColor + MIDSIZE)
  --lcd.drawText(x + 120, y + 6*lineHeight, "BATT " .. telemetryData.batt .. "A", textColor + MIDSIZE)
  -- Draw VOLTAGE
  lcd.drawText(x + labelWidth + 170, y + 6 * lineHeight, "VOLTAGE:" .. telemetryData.volt .. "V", textColor + MIDSIZE)

  local fullVoltage = 8.3
  local emptyVoltage = 6.7
  local batteryPercent = 0
  if telemetryData.batt > emptyVoltage then
    batteryPercent = (telemetryData.batt - emptyVoltage) / (fullVoltage - emptyVoltage) * 100
  end
  lcd.drawText(x + labelWidth + 300, y + lineHeight, math.floor(batteryPercent) .. "%", LEFT + MIDSIZE)
  lcd.drawText(x + 370, y + 2, "Batt:" .. string.format("%.1fV", telemetryData.batt), textColor + MIDSIZE)

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
  lcd.drawText(x + 2, y + 7 * lineHeight, "COMMAND" .. LastCommand, textColor + MIDSIZE)
  lcd.drawText(x + 202, y + 7 * lineHeight, "TYPE" .. Frame_type, textColor + MIDSIZE)
  --lcd.drawText(x+202,y+7*lineHeight,"COMMAND"..LastCommand,textColor+MIDSIZE)

  lcd.drawText(x + 2, y + 8 * lineHeight, "[2]" .. L_tmp, textColor + MIDSIZE)
  lcd.drawText(x + 102, y + 8 * lineHeight, "[3]" .. R_tmp, textColor + MIDSIZE)
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
