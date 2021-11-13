--[[
    menuManager
     - by PriestOfIlunibi
     - Written for TES3MP Version 0.7.0alpha
     - Build 2 (November 12th, 2021)

    How to install:
     1. Place this script in server\scripts\custom (or CoreScripts/scripts/custom on Linux).
     2. Add menuManager = require("custom.menuManager") to the end of server/scripts/customScripts.lua (copy and paste if need be)

    Creating menus:
         1. Use menuManager.create[menuType](<your chosen GUI ID>, <your menu definition>) in your script to allocate a new menu of the
            given type.
         2. You may then access your menu's data or have menuManager display it by calling menuManager.menu[<your chosen GUI ID>]:show(pid). See the
            code below for what other features menuManager supports.
         - If the identifier you chose was already in use, create() will return false and ignore the new menu request.
         - By default, the only requirement for showing a menu to a player is that said player must exist. Add a check to ensure the player is
            logged in through the requirements table.
         - See the example below for formatting.
         - Check testMenus.lua to see an example usage of menuManager.

     Changelog:
     - Creating menus from JSON no longer supported. Format your menus in Lua and use menuManager.create[menuType]() instead.
]]

local stringGSub = string.gsub
local Concat = table.concat

local menuManager = {}

menuManager.config = {
    logLevel = 1, -- The debugging levels from tes3mp-server-default.cfg + 1 (i.e verbose is 1, info is 2, etc)
    logImmutable = false -- If set to true, logs from this script that meet the logLevel requirement set above will always show in the server log.
}

menuManager.menu = { -- do not edit
    --[[ Example menu definition:
        [<your chosen idGui>] = {
            requirements = { -- Can have 0 length
                <fn that optionally takes a pid, returns a boolean or "bypass">,
                fn2,
                fn3,
                ...
            },
            list = {
                conditional = true
                [1] = {
                    text = <string/fn returning string>, -- Do not use ; or \n in CustomMessageBoxes or Listboxes, respectively.
                    conditions = { -- Can have 0 length
                        <fn that optionally takes a pid, returns a boolean or "bypass">,
                        fn2,
                        fn3,
                        ...
                    },
                    destination = <fn that optionally takes a pid and/or the 'data' return of GUI events>
                }
                [2] = <same format as 1>
                [3] = <same format as 1>
                ...
            },
            list = {
                conditional = false,
                [1] = <formatted string/fn returning formatted string>, -- all items/buttons in the menu
                [2] = {
                    [0] = <fn that optionally takes a PID and/or the 'data' return of GUI events> -- starts from 0 to match default menu behavior,
                    [1] = <same format as 0>
                    [2] = <same format as 0>
                    ...
                } OR <fn returning a table formatted as above>
            }
            label = <string/fn returning string>,
            note = <string/fn returning string>,
            hidden = <boolean/fn returning boolean>, -- Toggles a CustomDialog between an InputDialog and a PasswordDialog
            messageBox = <boolean/fn returning boolean>, -- Toggles a CustomList between a CustomMessageBox and a ListBox
            destinations = { -- for Dialogs
                [<expected data return>] = <fn that takes a pid and/or the 'data' return of GUI events>,
                ["\n"] = <fn> -- Normally unreachable 'default' return; optional (note that static lists can take advantage of this destination too)
            } OR <fn returning a table formatted as above>
        }
    ]]--
}

local playerDestinations = { -- do not edit
    --[[
        [<pid>] = {
            <idGui>, -- kept as a layer of protection against improper menu access attempts
            {<a copy of the valid button/item destinations for customLists, OR the 'destinations' table for Dialogs>}
        }
    ]]--
}

-- DRY principles taken to an extreme. Feel free to reuse this debugging system in your own scripts, as it carries a performance improvement.
local debugTypes = {"V","I","W","E","F"}
local debugTbl = {}
local indivLogLevel = 5 -- if logImmutable is true, then all logs are output at level 5; otherwise, it gets overwritten by the value of i
for i = 1, 5 do
    if menuManager.config.logLevel + 1 <= i then
        if not menuManager.config.logImmutable then indivLogLevel = i end
        debugTbl[ debugTypes[i] ] = {
            Table = function(...) return tes3mp.LogMessage(indivLogLevel,Concat{...}) end,
            Quick = function(msg) return tes3mp.LogMessage(indivLogLevel,msg) end
        }
    else
        debugTbl [debugTypes[i] ] = {
            Table = function() end,
            Quick = function() end
        }
    end
end

-- logDebug is used for logging a message with multiple items; quickDebug is used for logging a singular string
local logDebugV = debugTbl.V.Table
local quickDebugV = debugTbl.V.Quick

local logDebugI = debugTbl.I.Table
local quickDebugI = debugTbl.I.Quick

local logDebugW = debugTbl.W.Table
local quickDebugW = debugTbl.W.Quick

local logDebugE = debugTbl.E.Table
local quickDebugE = debugTbl.E.Quick

local logDebugF = debugTbl.F.Table
local quickDebugF = debugTbl.F.Quick

-- MISC FUNCTIONS --

local function getParam(pid, obj)
    if type(obj) == "function" then return obj(pid) end
    return obj
end

local function checkAuth(pid, list, sep)
    local outDisplay, destinations = {}, {}

    local status = true
    local object, objectConditions
    local dstIndex = 0
    for i = 1, #list do
        object = list[i]
        objectConditions = object.conditions or {}
        for j = 1, #objectConditions do
            status = objectConditions[j](pid)
            if not status then
                break
            elseif status == "bypass" then
                status = true
                break
            end
        end
        if status then
            outDisplay[#outDisplay+1] = stringGSub(getParam(pid, object.text), sep, '')
            destinations[dstIndex] = object.destination
            dstIndex = dstIndex + 1
        else status = true end
    end

    outDisplay = Concat(outDisplay, sep)
    return outDisplay, destinations
end

-- MENU CLASS DEFINITIONS --

local menuClass = {requirements = {}}
function menuClass:new(newMenuClass)
    newMenuClass = newMenuClass or {}
    setmetatable(newMenuClass, self)
    self.__index = self
    return newMenuClass
end
function menuClass:checkRequirements(pid)
    logDebugI("Checking requirements for ",Players[pid].name," (",tostring(pid),")")
    local status
    for i = 1, #self.requirements do
        status = self.requirements[i](pid)
        if not status then
            return false
        elseif status == "bypass" then
            return true
        end
    end

    return true
end

local messageBoxClass = menuClass:new{label = ""}
function messageBoxClass:new(idGui, newMessageBox)
    if menuManager.menu[idGui] then
        return false
    end

    newMessageBox = newMessageBox or {}

    newMessageBox.idGui = idGui
    setmetatable(newMessageBox, self)
    self.__index = self
    menuManager.menu[idGui] = newMessageBox
    return true
end
function messageBoxClass:show(pid, label)
    if not Players[pid] or (#self.requirements > 0 and not self:checkRequirements(pid)) then return false end

    label = label or getParam(pid, self.label)

    tes3mp.MessageBox(pid, self.idGui, label)
    return true
end

-- CustomMessageBox and ListBox share the same class, since they share similar parameters. By default they are set to show as MessageBoxes.
local customListClass = menuClass:new({label = "", list = {conditional = false, "", {}}, messageBox = true})
function customListClass:new(idGui, newCustomList)
    if menuManager.menu[idGui] then
        return false
    end

    newCustomList = newCustomList or {}

    newCustomList.idGui = idGui
    setmetatable(newCustomList, self)
    self.__index = self
    menuManager.menu[idGui] = newCustomList
    return true
end
function customListClass:show(pid, label, list, messageBox)
    if not Players[pid] or (#self.requirements > 0 and not self:checkRequirements(pid)) then
        return false
    end

    label = label or getParam(pid, self.label)
    messageBox = messageBox or self.messageBox
    list = list or self.list

    local displayList
    playerDestinations[pid] = {self.idGui}
    if not list.conditional then
        displayList = getParam(pid, list[1])
        playerDestinations[pid][2] = getParam(pid, list[2])
    else
        if messageBox then
            displayList, playerDestinations[pid][2] = checkAuth(pid, list, ";")
        else
            displayList, playerDestinations[pid][2] = checkAuth(pid, list, "\n")
        end
    end

    if messageBox then
        tes3mp.CustomMessageBox(pid, self.idGui, label, displayList)
    else
        tes3mp.ListBox(pid, self.idGui, label, displayList)
    end
    return true
end

-- InputDialog and PasswordDialog share the same class, since they take the same parameters. By default they are set to show as InputDialogs.
local dialogClass = menuClass:new({label = "", note = "", hidden = false, destinations = {}})
function dialogClass:new(idGui, newDialog)
    if menuManager.menu[idGui] then
        return false
    end

    newDialog = newDialog or {}

    newDialog.idGui = idGui
    setmetatable(newDialog, self)
    self.__index = self
    menuManager.menu[idGui] = newDialog
    return true
end
function dialogClass:show(pid, label, note, hidden, destinations)
    if not Players[pid] or (#self.requirements > 0 and not self:checkRequirements(pid)) then
        return false
    end

    label = label or getParam(pid, self.label)
    note = note or getParam(pid, self.note)
    hidden = hidden or getParam(pid, self.hidden)
    destinations = destinations or getParam(pid, self.destinations)
    playerDestinations[pid] = {self.idGui,destinations}

    if hidden then
        tes3mp.PasswordDialog(pid, self.idGui, label, note)
    else
        tes3mp.InputDialog(pid, self.idGui, label, note)
    end
    return true
end

menuManager.create = {
    -- actual classes
    MessageBox = function(idGui, newMessageBox) return messageBoxClass:new(idGui, newMessageBox) end,
    CustomList = function(idGui, newCustomList) return customListClass:new(idGui, newCustomList) end,
    Dialog = function(idGui, newDialog) return dialogClass:new(idGui, newDialog) end,

    -- aliases with specific settings
    CustomMessageBox = function(idGui, newCustomMessageBox)
        newCustomMessageBox.messageBox = true
        return customListClass:new(idGui, newCustomMessageBox)
    end,
    ListBox = function(idGui, newListBox)
        newListBox.messageBox = false
        return customListClass:new(idGui, newListBox)
    end,

    InputDialog = function(idGui, newInputDialog)
        newInputDialog.hidden = false
        return dialogClass:new(idGui, newInputDialog)
    end,
    PasswordDialog = function(idGui, newPasswordDialog)
        newPasswordDialog.hidden = true
        return dialogClass:new(idGui, newPasswordDialog)
    end
}

-- EVENT HANDLERS --

local function wipeDst(eventStatus, pid) playerDestinations[pid] = nil end

local function GUIActionHandler(eventStatus, pid, idGui, data)
    if Players[pid] and playerDestinations[pid] and playerDestinations[pid][1] == idGui then
        local destinations = playerDestinations[pid][2] or {
            ["\n"] = function()
                logDebugW("[menuManager]: The destinations table for menu ",idGui," is improperly formatted!")
            end
        }
        local finalDestination

        if tonumber(data) then data = tonumber(data)
        elseif string.find(data,"%c") then
            logDebugW("[menuManager]: Detected impossible user input from PID",tostring(pid))
            return
        end

        if destinations[data] then
            finalDestination = destinations[data]
        elseif destinations["\n"] then
            finalDestination = destinations["\n"]
        else
            return
        end

        playerDestinations[pid] = nil

        finalDestination(pid, data)
    end
end

customEventHooks.registerHandler("OnGUIAction", GUIActionHandler)
customEventHooks.registerHandler("OnPlayerConnect", wipeDst)
customEventHooks.registerHandler("OnPlayerDisconnect", wipeDst)

return menuManager