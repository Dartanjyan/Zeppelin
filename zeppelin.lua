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

FUEL_CAPACITY = 1656000
FUEL = 0
FUEL_CONSUMPTION = 0  -- in seconds
FUEL_SECONDS_LEFT = 0

local lastFuel = 0
local function calculateFuelConsumption()
    FUEL = fluidTank.tanks()[1].amount
    local deltaFuel = FUEL - lastFuel

    FUEL_CONSUMPTION = deltaFuel

    os.sleep(1)
end

local function updateMonitor()
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Fuel: " .. math.floor(FUEL / 1000 + 0.5) .. "B")

    os.sleep(1)
end

print("Start Zeppelin")

parallel.waitForAll(
    updateMonitor
)