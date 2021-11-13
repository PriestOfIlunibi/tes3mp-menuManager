local Concat = table.concat

local function testFunction(pid, x, idGui)
    local message = "testFunction result is " .. x
    tes3mp.LogMessage(1, "[exampleManagedMenu]: " .. message)
    tes3mp.SendMessage(pid, message .. "\n")
    return menuManager.menu[idGui]:show(pid)
end

local function playerListLabel()
    local playerCount = logicHandler.GetConnectedPlayerCount()
    local label = {playerCount, " connected player"}
    if playerCount ~= 1 then label[2] = " connected players"
    else label[2] = " connected player" end
    label[3] = "\nThis is just a copy of the default playerlist function."
    return Concat(label)
end

local function playerList()
    local lastPid = tes3mp.GetLastPlayerId()
    local list = {}
    local sep = "\n"
    local listLen
    for playerIndex = 0, lastPid do
        if Players[playerIndex] ~= nil and Players[playerIndex]:IsLoggedIn() then
            listLen = #list+1 -- minimize function calls
            list[listLen] = tostring(Players[playerIndex].name)
            list[listLen+1] = " (pid: "
            list[listLen+2] = tostring(Players[playerIndex].pid)
            list[listLen+3] = ", ping: "
            list[listLen+4] = tostring(tes3mp.GetAvgPing(Players[playerIndex].pid))
            list[listLen+5] = ")"
            if not playerIndex == lastPid then list[listLen+6] = sep end
        end
    end
    return Concat(list)
end

local function makeShowMenu(idGui) return function(pid) return menuManager.menu[idGui]:show(pid) end end
local function makeShowDialog779005(hidden)
    local label
    if hidden then label = "This is just a PasswordDialog."
    else label = "This is just an InputDialog." end
    return function(pid) return menuManager.menu[779005]:show(pid, label, nil, hidden) end
end
local function makeTestFunction(x, idGui) return function(pid) return testFunction(pid, x, idGui) end end

local menus = {
    [779000] = {
        requirements = {function(pid) return Players[pid]:IsLoggedIn() end},
        label = "This is the 'main' menu, or example CustomMessageBox one.\nNote how it is formatted in the Lua file.",
        list = {
            conditional = true,
            {
                text = "Run testFunction case 0",
                conditions = {function(pid) return pid == 0 end},
                destination = makeTestFunction(0, 779000)
            },
            {
                text = "Show example CustomMessageBox two",
                conditions = {},
                destination = makeShowMenu(779001)
            },
            {
                text = "Show example CustomMessageBox three",
                destination = makeShowMenu(779002)
            },
            {
                text = "Show example ListBox",
                destination = makeShowMenu(779003)
            },
            {
                text = "Show example _MessageBox",
                destination = makeShowMenu(779004)
            },
            {
                text = "Show example InputDialog",
                destination = makeShowDialog779005(false)
            },
            {
                text = "Show example PasswordDialog",
                destination = makeShowDialog779005(true)
            },
            {text = "Exit menu"}
        }
    },
    [779001] = {
        requirements = {},
        label = "This is example menu two.\nNote that it can swap between being a CustomMessageBox and a ListBox.",
        list = {
            conditional = false,
            function() -- Note that since this non-conditional CustomList swaps between CustomMessageBox and ListBox, it must handle using proper separators for each.
                if menuManager.menu[779001].messageBox then return "Go back to main menu;Run testFunction case 1;Swap menu type"
                else return "Go back to main menu\nRun testFunction case 1\nSwap menu type" end
            end,
            {
                [0] = makeShowMenu(779000),
                makeTestFunction(1, 779001),
                function(pid)
                    menuManager.menu[779001].messageBox = not menuManager.menu[779001].messageBox
                    return menuManager.menu[779001]:show(pid)
                end
            }
        }
    },
    [779002] = {
        label = function(pid) return "This is example menu three, " .. Players[pid].name end,
        list = {
            conditional = false,
            "Go back to main menu;Run testFunction case 2",
            {
                [0] = makeShowMenu(779000),
                makeTestFunction(2, 779002)
            }
        }
    },
    [779003] = {
        label = playerListLabel,
        list = {
            conditional = false,
            playerList,
            {["\n"] = makeShowMenu(779000)}
        }
    },
    [779004] = {
        label = "This is just a _MessageBox."
    },
    [779005] = {
        -- We don't define a label or the hidden status, as they're set by the function that calls it
        note = "It is reused for both Input and Password menus, just with the state changed.",
        destinations = {["\n"] = makeShowMenu(779000)}
    }
}

local function createMenus() -- Done at PostInit to ensure menuManager is ready
    menuManager.create.CustomList(779000, menus[779000])
    menuManager.create.ListBox(779003, menus[779003])
    menuManager.create.CustomList(779001, menus[779001])
    menuManager.create.CustomMessageBox(779002, menus[779002])
    menuManager.create.MessageBox(779004, menus[779004])
    menuManager.create.Dialog(779005, menus[779005])
end

-- We don't even need to do the login/valid PID checks; it's defined in our menu's requirements for the former and menuManager itself for the latter!
local function showMain(pid) return menuManager.menu[779000]:show(pid) end

customEventHooks.registerHandler("OnServerPostInit",createMenus)
customCommandHooks.registerCommand("TestManagedMenu",showMain)