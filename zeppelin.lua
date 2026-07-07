local rslink = peripheral.find("redstone_link_bridge")
local keyboard = peripheral.find("tm_keyboard")
local monitor = peripheral.find("monitor")

-- Если включен рычаг на частоте "simulated:linked_typewriter", "simulated:linked_typewriter" то мы в режиме автопилота,
-- иначе в мануальном режиме

--[[
    В мануальном режиме
    W: вперёд
    S: назад
    A: влево
    D: вправо
    R: вверх
    F: вниз
]]

FREQUENCIES = {
    autopilot = {"simulated:linked_typewriter", "simulated:linked_typewriter"},

    KEYS = {
        forward = {"simulated:linked_typewriter", "minecraft:white_wool"},
        left = {"simulated:linked_typewriter", "minecraft:light_gray_wool"},
        back = {"simulated:linked_typewriter", "minecraft:gray_wool"},
        right = {"simulated:linked_typewriter", "minecraft:black_wool"},
        up = {"simulated:linked_typewriter", "minecraft:brown_wool"},
        down = {"simulated:linked_typewriter", "minecraft:red_wool"}
    },
    THRUSTERS = {
        main = {"createpropulsion:thruster", "createpropulsion:thruster"},
        frontLeft = {"createpropulsion:thruster", "minecraft:white_wool"},
        frontRight = {"createpropulsion:thruster", "minecraft:light_gray_wool"},
        backLeft = {"createpropulsion:thruster", "minecraft:gray_wool"},
        backRight = {"createpropulsion:thruster", "minecraft:black_wool"},
        steamVent = {"aeronautics:steam_vent", "aeronautics:steam_vent"}
    }
}

local function getLinkSignal(frequencies)
    return rslink.getLinkSignal(frequencies[1], frequencies[2])
end

local function setLinkSignal(frequencies, signal)
    rslink.setLinkSignal(frequencies[1], frequencies[2], signal)
end

local function isAutopilotEnabled()
    return getLinkSignal(FREQUENCIES.autopilot)
end

print("Start Zeppelin")

while true do
    if not isAutopilotEnabled() then
        setLinkSignal(FREQUENCIES.THRUSTERS.main(getLinkSignal(FREQUENCIES.KEYS.forward)))
    end

    os.sleep(0)
end