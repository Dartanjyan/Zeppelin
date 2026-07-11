local rsRelay = peripheral.find("redstone_relay")
local monitor = peripheral.find("monitor")
local fluidTank = peripheral.find("create:fluid_tank")
local navTable = peripheral.find("navigation_table")
-- local keyboard = peripheral.find("tm_keyboard")

local function humanizeTime(seconds)
    if seconds <= 0 then return "infinite" end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    local parts = {}
    if hours > 0 then table.insert(parts, hours .. "h") end
    if minutes > 0 then table.insert(parts, minutes .. "m") end
    if secs > 0 then table.insert(parts, secs .. "s") end

    return table.concat(parts, " ")
end

local function validateCoordinates(input)
    -- 1. Удаляем лишние пробелы по бокам
    local trimmed = input:gsub("^%s+", ""):gsub("%s+$", "")

    -- 2. Проверяем формат с помощью шаблона:
    -- ^       - начало строки
    -- (-?%d+) - первое целое число (опционально с минусом)
    -- %s+     - один или более пробелов
    -- (-?%d+) - второе целое число
    -- $       - конец строки
    local str1, str2 = trimmed:match("^(-?%d+)%s+(-?%d+)$")

    -- 3. Если совпадений нет — возвращаем false
    if not str1 or not str2 then
        return false, nil, nil
    end

    -- 4. Преобразуем в числа
    local n1 = tonumber(str1)
    local n2 = tonumber(str2)

    return true, n1, n2
end

local function humanizeDistance(meters)
    -- Защита от некорректных данных
    if not meters or meters < 0 then return "0 m" end

    if meters < 1000 then
        -- Для метров округляем до целого числа
        return string.format("%.0f m", meters)
    else
        local kilometers = meters / 1000
        
        -- Если деление ровное (например, 2000 м -> 2 км), убираем .0
        if kilometers % 1 == 0 then
            return string.format("%.0f km", kilometers)
        else
            -- Если есть дробная часть, оставляем 1 знак после запятой (например, 1.3 км)
            return string.format("%.1f km", kilometers)
        end
    end
end

local function clamp(x, min, max)
    return math.min(max, math.max(min, x))
end

local function loadConfig(path)
    if not fs.exists(path) then error("Config not found: " .. path) end
    local file = fs.open(path, "r")
    local data = textutils.unserializeJSON(file.readAll())
    file.close()
    return data
end

local config = loadConfig("config.json")

local function getAirshipPosition()
    if not navTable then return nil, "Table not found" end

    -- 1. Получаем данные
    -- ВАЖНО: Проверь знак. Если getHeading дает -90, а должен быть 90, 
    -- убери или добавь минус перед вызовом.
    local yawDeg = -navTable.getHeading() 
    local dist = navTable.getDistanceToTarget()
    
    -- Переводим yaw в радианы
    local yawRad = math.rad(yawDeg)

    -- 2. Вычисляем смещение от якоря до дирижабля
    -- Если стол показывает "направление на якорь", то дирижабль находится 
    -- с противоположной стороны от якоря.
    local dx = dist * math.sin(yawRad)
    local dz = dist * math.cos(yawRad)

    -- 3. Вычисляем координаты дирижабля
    -- Если стол смотрит на якорь, то дирижабль находится в (AnchorX - dx, AnchorZ - dz)
    local shipX = config.anchor_pos[1] - dx
    local shipZ = config.anchor_pos[2] - dz

    return {
        x = shipX,
        z = shipZ,
        yaw = yawDeg
    }
end

AUTOPILOT_STATES = {
    PAUSED = 1,
    RUNNING = 2,
    ERROR = 3
}

-- GLOBAL STATE --
FUEL_CAPACITY = 1656000
FUEL = 0
FUEL_CONSUMPTION = 0  -- in seconds
FUEL_SECONDS_LEFT = 0

TARGET_X = 0
TARGET_Z = 0
TARGET_INPUT_BUFFER = ""

AUTOPILOT_STATE = AUTOPILOT_STATES.PAUSED

SHIP_SPEED = 0
SHIP_YAW = 0

X, ALTITUDE, Z = 0, 0, 0

local lastFuel = 0
local function calculateFuelConsumption()
    while true do
        FUEL = fluidTank.tanks()[1].amount
        FUEL_CONSUMPTION = -(FUEL - lastFuel)
        lastFuel = FUEL
        if FUEL_CONSUMPTION == 0 then
            FUEL_SECONDS_LEFT = -1
        else
            FUEL_SECONDS_LEFT = FUEL / FUEL_CONSUMPTION
        end
        os.sleep(2)
    end
end

local lastX, lastZ, lastClock = 0, 0, 0

local function calculateSpeedAndDirection()
    while true do
        -- local x, ALTITUDE, z = gps.locate()
        local telemetry = getAirshipPosition()
        if telemetry then
            local clock = os.clock()
            SHIP_YAW = telemetry.yaw
            
            local dx, dz = telemetry.x - lastX, telemetry.z - lastZ
            SHIP_SPEED = math.sqrt(dx * dx + dz * dz) / (clock - lastClock)
            
            lastX, lastZ = telemetry.x, telemetry.z
            X, Z = telemetry.x, telemetry.z
            lastClock = clock
        else
            print(err)
        end
        os.sleep(1)
    end
end

local function isAutopilotLeverEnabled()
    return rsRelay.getInput("top")
end

local function autopilot()
    while true do
        if AUTOPILOT_STATE == AUTOPILOT_STATES.RUNNING and isAutopilotLeverEnabled() then
            -- Рассчитать нужный угол
            -- Градационно в зависимости от ошибки угла подстраивать курс
            
            -- Вектор направления на цель
            local dx = TARGET_X - X
            -- Применяем ту же инверсию для Z, которая сработала у вас
            local dz = Z - TARGET_Z

            -- Вычисляем угол в радианах и переводим в градусы
            local radians = math.atan2(dx, dz)
            local targetDegrees = math.deg(radians)

            local directionError = targetDegrees - SHIP_YAW
            if directionError > 180 then directionError = directionError - 360
            elseif directionError < -180 then directionError = directionError + 360
            end

            -- 180 макс
            -- 0 это мин
            -- -180 макс в другую сторону
            -- Газ: максимальный при 0 ошибке
            -- Поворот направо: макс при ошибке 180 и мин при 0
            -- Поворот налево: макс при ошибке -180 и минимум при нуле

            -- thr = (-16)/180
            local throttle = (-16)/180 * math.abs(directionError) + 16
            local rightTurn = 16/180 * directionError
            local leftTurn = -rightTurn

            rsRelay.setAnalogOutput("left", clamp(leftTurn, 0, 15))
            rsRelay.setAnalogOutput("right", clamp(rightTurn, 0, 15))
            rsRelay.setAnalogOutput("front", clamp(throttle, 0, 15))
        else
            rsRelay.setAnalogOutput("left", 0)
            rsRelay.setAnalogOutput("right", 0)
            rsRelay.setAnalogOutput("front", 0)
        end
        os.sleep(1)
    end
end

local function userInput()
    -- Пробел ставит пробел между координатами code 32
    -- Минус code 45
    -- Все цифровые ивенты и пробел это набор координат code 48 - 57
    -- Enter это переключение состояния автопилота code 257
    -- Backspace ставит автопилот на паузу и стирает цифру координат code 259
    -- 320 - 329 цифры нампад

    while true do
        local _, _, key = os.pullEvent("tm_keyboard_key")
        -- "tm_keyboard_key", "top", keyCode, continuous
        -- print(key)
        local symbol = ""

        if AUTOPILOT_STATE == AUTOPILOT_STATES.RUNNING then
            AUTOPILOT_STATE = AUTOPILOT_STATES.PAUSED
        end

        if key == 32 then symbol = " "
        elseif key == 45 then symbol = "-"
        elseif key >= 48 and key <= 57 then symbol = tostring(key - 48)
        elseif key >= 320 and key <= 329 then symbol = tostring(key - 320)
        elseif key == 257 then
            --[[if AUTOPILOT_STATE == AUTOPILOT_STATES.RUNNING then
                AUTOPILOT_STATE = AUTOPILOT_STATES.PAUSED
            else]]if AUTOPILOT_STATE == AUTOPILOT_STATES.PAUSED or AUTOPILOT_STATE == AUTOPILOT_STATES.ERROR then
                local success, x, z = validateCoordinates(TARGET_INPUT_BUFFER)
                if success then
                    TARGET_INPUT_BUFFER = x .. " " .. z
                    TARGET_X = x
                    TARGET_Z = z
                    AUTOPILOT_STATE = AUTOPILOT_STATES.RUNNING
                else
                    AUTOPILOT_STATE = AUTOPILOT_STATES.ERROR
                end
            end
        elseif key == 259 then
            if AUTOPILOT_STATE == AUTOPILOT_STATES.RUNNING or AUTOPILOT_STATE == AUTOPILOT_STATES.ERROR then
                AUTOPILOT_STATE = AUTOPILOT_STATES.PAUSED
            end
            if #TARGET_INPUT_BUFFER > 0 then
                TARGET_INPUT_BUFFER = string.sub(TARGET_INPUT_BUFFER, 1, -2)
            end
        end

        TARGET_INPUT_BUFFER = TARGET_INPUT_BUFFER .. symbol
    end
end

local function handlePaste()
    while true do
        
    end
end

local function updateMonitor()
    while true do
        monitor.setTextColor(colors.white)
        monitor.setBackgroundColor(colors.black)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write("Fuel: " .. math.floor(FUEL / FUEL_CAPACITY * 1000) / 10 .. "%")
        monitor.setCursorPos(1, 2)
        monitor.write("Consumption: " .. FUEL_CONSUMPTION/1000 .. " B/s")
        monitor.setCursorPos(1, 3)
        monitor.write("Time left: " .. humanizeTime(FUEL_SECONDS_LEFT))

        -- Autopilot status bar
        monitor.setCursorPos(1, 5)
        monitor.setTextColor(colors.black)
        if AUTOPILOT_STATE == AUTOPILOT_STATES.RUNNING then
            -- monitor.setBackgroundColor(colors.lime)
            -- monitor.clearLine()
            monitor.setTextColor(colors.lime)
            monitor.write("AUTOPILOT STATE: RUNNING")
        elseif AUTOPILOT_STATE == AUTOPILOT_STATES.PAUSED then
            -- monitor.setBackgroundColor(colors.lightBlue)
            -- monitor.clearLine()
            monitor.setTextColor(colors.lightBlue)
            monitor.write("AUTOPILOT STATE: PAUSED")
        elseif AUTOPILOT_STATE == AUTOPILOT_STATES.ERROR then
            -- monitor.setBackgroundColor(colors.red)
            -- monitor.clearLine()
            monitor.setTextColor(colors.red)
            monitor.write("AUTOPILOT STATE: ERROR")
        end
        
        monitor.setCursorPos(1, 4)
        monitor.clearLine()
        monitor.setCursorPos(1, 6)
        monitor.clearLine()
        -- Autopilot status bar

        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)

        monitor.setCursorPos(1, 7)
        monitor.write("Target: " .. TARGET_INPUT_BUFFER)
        monitor.setCursorPos(1, 8)
        monitor.write("Speed: " .. math.floor(SHIP_SPEED * 3.6 * 100) / 100 .. " km/h")
        if isAutopilotLeverEnabled() then
            local dx, dz = TARGET_X - X, TARGET_Z - Z
            local distance = math.sqrt(dx * dx + dz * dz)
            monitor.setCursorPos(1, 9)
            monitor.write("Distance: " .. humanizeDistance(distance))
            monitor.setCursorPos(1, 10)
            monitor.write("Time left: " .. humanizeTime(distance / SHIP_SPEED))
        end

        monitor.setCursorPos(1, 11)
        monitor.write("Yaw: " .. math.floor(SHIP_YAW*10)/10)

        os.sleep(0)
    end
end

print("Start Zeppelin")

parallel.waitForAll(
    calculateFuelConsumption,
    updateMonitor,
    userInput,
    calculateSpeedAndDirection,
    autopilot
)