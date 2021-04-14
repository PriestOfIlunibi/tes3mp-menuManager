--[[
	For demonstration purposes only.
]]

local exampleManagedMenu = {}

function exampleManagedMenu.testFunction(pid, case, returnIdGui)
	local message = "testFunction result is " .. case
	tes3mp.LogMessage(1, "[INFO]exampleManagedMenu: ".. message)
	tes3mp.SendMessage(pid, message .. "\n")
	return menuManager.GUIActionHandler(pid, returnIdGui, -1) -- Calls to the GUIActionHandler to look up a function return value (a negative number that cannot be reached by a menu's buttons normally) for the menu that called testFunction. You can also use menuManager.showMenu(pid, returnIdGui) (which helps for debugging purposes), however this way allows for more dynamic control flow as well as hooking into the "any" return (if you wanted this function to call that instead of a specific return type).
end

function exampleManagedMenu.CustomMessageBoxLabel()
	return "This is example menu three.\nNote that its buttons are already concatenated together as a formatted string, and that this label is returned from an external function."
end

function exampleManagedMenu.playerListLabel() -- shamelessly stolen from guiHelper.lua for this demonstration
	local playerCount = logicHandler.GetConnectedPlayerCount()
    local label = playerCount .. " connected player"

    if playerCount ~= 1 then
        label = label .. "s"
    end
	label = label .. "\nThis is just a copy of the default playerlist function."
	return label
end

function exampleManagedMenu.playerList() -- also stolen from guiHelper.lua for this demonstration
    local lastPid = tes3mp.GetLastPlayerId()
    local list = ""
    local divider = ""

    for playerIndex = 0, lastPid do
        if playerIndex == lastPid then
            divider = ""
        else
            divider = "\n"
        end
        if Players[playerIndex] ~= nil and Players[playerIndex]:IsLoggedIn() then

            list = list .. tostring(Players[playerIndex].name) .. " (pid: " .. tostring(Players[playerIndex].pid) ..
                ", ping: " .. tostring(tes3mp.GetAvgPing(Players[playerIndex].pid)) .. ")" .. divider
        end
    end

    return list
end

function exampleManagedMenu.showMenu(pid, cmd)
	menuManager.showMenu(pid, 779000)
end

customCommandHooks.registerCommand("TestManagedMenu",exampleManagedMenu.showMenu)

return exampleManagedMenu