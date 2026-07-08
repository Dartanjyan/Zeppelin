local rslink = peripheral.find("redstone_link_bridge")
local keyboard = peripheral.find("tm_keyboard")
local monitor = peripheral.find("monitor")
local fluidTank = peripheral.find("create:fluid_tank")

local function getLinkSignal(frequencies)
    return rslink.getLinkSignal(frequencies[1], frequencies[2])
end

local function sendLinkSignal(frequencies, signal)
    rslink.sendLinkSignal(frequencies[1], frequencies[2], signal)
end

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

FREQUENCIES = {
    THRUSTERS = {
        main = {"createpropulsion:thruster", "createpropulsion:thruster"},
        frontLeft = {"createpropulsion:thruster", "minecraft:white_wool"},
        frontRight = {"createpropulsion:thruster", "minecraft:light_gray_wool"},
        backLeft = {"createpropulsion:thruster", "minecraft:gray_wool"},
        backRight = {"createpropulsion:thruster", "minecraft:black_wool"},
        steamVent = {"aeronautics:steam_vent", "aeronautics:steam_vent"}
    }
}

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

local function autopilot()
    -- Проверить включен ли автопилот
    -- Взять координаты целевые и лететь туда
    while true do
        if AUTOPILOT_STATE == AUTOPILOT_STATES.RUNNING then
            local x, y, z = gps.locate()
        end
    end
end

local function userInput()
    -- Пробел ставит пробел между координатами code 32
    -- Минус code 45
    -- Все цифровые ивенты и пробел это набор координат code 48 - 57
    -- Enter это переключение состояния автопилота code 257
    -- Backspace ставит автопилот на паузу и стирает цифру координат code 259

    while true do
        local _, _, key = os.pullEvent("tm_keyboard_key")
        -- "tm_keyboard_key", "top", keyCode, continuous
        print(key)
        local symbol = ""
        if key == 32 then symbol = " "
        elseif key == 45 then symbol = "-"
        elseif key >= 48 and key <= 57 then symbol = tostring(key - 48)
        elseif key == 257 then
            if AUTOPILOT_STATE == AUTOPILOT_STATES.RUNNING then
                AUTOPILOT_STATE = AUTOPILOT_STATES.PAUSED
            elseif AUTOPILOT_STATE == AUTOPILOT_STATES.PAUSED or AUTOPILOT_STATE == AUTOPILOT_STATES.ERROR then
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
            monitor.setBackgroundColor(colors.lime)
            monitor.clearLine()
            monitor.write("AUTOPILOT STATE: RUNNING")
        elseif AUTOPILOT_STATE == AUTOPILOT_STATES.PAUSED then
            monitor.setBackgroundColor(colors.lightBlue)
            monitor.clearLine()
            monitor.write("AUTOPILOT STATE: PAUSED")
        end
        monitor.setCursorPos(1, 4)
        monitor.clearLine()
        -- Autopilot status bar

        -- Разделитель
        -- Статус бар автопилота
        -- Координаты цели
        -- Остальная инфа
        os.sleep(1)
    end
end

print("Start Zeppelin")

parallel.waitForAll(
    calculateFuelConsumption,
    updateMonitor,
    userInput
)