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

-- GLOBAL STATE --
FUEL_CAPACITY = 1656000
FUEL = 0
FUEL_CONSUMPTION = 0  -- in seconds
FUEL_SECONDS_LEFT = 0


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
        os.sleep(1)
    end
end

local function updateMonitor()
    while true do
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write("Fuel: " .. math.floor(FUEL / FUEL_CAPACITY * 1000) / 10 .. "%")
        monitor.setCursorPos(1, 2)
        monitor.write("Consumption: " .. FUEL_CONSUMPTION/1000 .. " B/s")
        monitor.setCursorPos(1, 3)
        monitor.write("Time left: " .. humanizeTime(FUEL_SECONDS_LEFT))
        os.sleep(1)
    end
end

print("Start Zeppelin")

parallel.waitForAll(
    calculateFuelConsumption,
    updateMonitor
)