--[[
	MenuManager
	 - by Dagoth Gares (Dagoth Gares#7777 on Discord, or join the TrueSTL Discord and ask for me there https://discord.gg/0ySoRImmzLUbKLAQ )
	 - Written for TES3MP Version 0.7.0alpha
	 - Build 1 (May 16, 2020)

	How to install:
	 1. Create a folder called 'menuManager' in server\scripts\custom, and place this script there.
	 2. Add menuManager = require("custom.menuManager.base") to the end of server/scripts/customScripts.lua (copy and paste if need be)
	 3. For any menu that must be added, add the path of the file to be loaded to the 'sources' table, formatted in the same manner as the example.
	 4. Remember to add accompanying lua scripts for each added menu, if necessary.
	
	Scripters:
	 - Check managedmenus/exampleManagedMenu.txt for a short guide on how to use menuManager and the features it offers.
	 - Use exampleManagedMenu.lua and exampleManagedMenu.json together to see how menuManager works in practice.
]]

local jsonInterface = require("jsonInterface")

-- localized function calls because this makes a lot of them
local jsonLoad = jsonInterface.load
local stringGSub = string.gsub
local stringFind = string.find
local stringMatch = string.match
local tableInsert = table.insert
local tableConcat = table.concat

local menuManager = {}

local lookup = {}

local customGui = {}

-- CONFIG --

local mMCfg = {}

mMCfg.logging = true -- Allows MenuManager to log information to your server's .log file. Generally recommended to be kept on unless a lot of menus are being added.
mMCfg.debugging = false -- Allows MenuManager to log debug information to your server's .log file. Generally recommended to be kept off unless you need to do debugging for this script or are adding new menus through it. tl;dr turn this on when asked to or at own discretion

local sources = { -- Add the locations of menu files here.
--"custom/managedmenus/exampleManagedMenu.json"

}

-- LOGGING --

local function serverError(message)
	tes3mp.LogMessage(3, "[ERROR]MenuManager: " .. message)
end

local function serverWarn(message)
	tes3mp.LogMessage(2, " [WARN]MenuManager: " .. message)
end

local function serverLog(message)
	if mMCfg.logging then
		tes3mp.LogMessage(1, " [INFO]MenuManager: " .. message)
	end
end

local function serverDebug(message)
	if mMCfg.debugging then
		tes3mp.LogMessage(0, "[DEBUG]MenuManager: " .. message)
	end
end

-- OTHER --

local function getFileNameNoExtension(fileName) -- In order to get the actual script name we're loading these menus for, we need to peel off the directories and the filename extension at the end
	fileName = stringMatch(fileName,"[^/]+$") -- only take the filename by looking at everything after the last / character
	fileName = stringGSub(fileName,"%.%a+", "") -- cut off the extension by replacing the period and everything after it with blank space. Also deletes trailing extensions (.txt.json), just to be sure.
	return fileName
end

-- RUNTIME COMPILERS --

local function destinationCompiler(destinationTable)
	serverDebug("destinationFormattingHandler: Started")
	local compiledDestinations = {}
	for i, func in pairs(destinationTable) do
		if tonumber(i) then -- lua will read the key as a string by default unless i tell it not to
			i = tonumber(i)
		end
		serverDebug("	- Supposed to compile function \"" .. func .. "\" |into slot " .. i .. ", slottype " .. type(i))
		local compiledDestination = load(func, nil, "t")
		compiledDestinations[i] = compiledDestination
	end
	return compiledDestinations
end

local function stringCompiler(argString)
	serverDebug("stringCompiler: Started")
	if stringFind(argString,"^/f") then -- checks if it starts with the two characters that identify it as a function
		argString = stringGSub(argString,"[/f]","",2) -- trim the identifier
		serverDebug("	- Supposed to compile label/note function \"" .. argString .. "\" |as function")
		compiledString = load(argString, nil, "t") -- loads it. I would strongly suggest using this as a middleman to return a function defined in your .lua instead as formatting a .json string to create a lua function is painful
	elseif stringFind(argString,"^/s") then -- not explicitly required but you can identify string returns with /s to easily tell the difference between function and string labels/notes at a glance
		serverDebug("	- Supposed to format string \"" .. argString .. "\" |as string")
		argString = stringGSub(argString,"[/s]","",2)
		compiledString = stringMatch(argString, '^()%s*$') and '' or stringMatch(argString, '^%s*(.*%S)') -- trim any preceding or trailing whitespace so it displays properly
	else -- presume it's a string
		serverDebug("	- Supposed to format string \"" .. argString .. "\" |as string")
		compiledString = stringMatch(argString, '^()%s*$') and '' or stringMatch(argString, '^%s*(.*%S)')
	end
	return compiledString
end

-- MENU INITIALIZERS --

local function initStatic_MB(fileName, menuName, idGui, argLabel)
	if lookup[idGui] ~= nil then
		error("initStatic_MB: Lookup result for ID " .. idGui .. " already exists! Result: " .. lookup[idGui])
	end
	lookup[idGui] = fileName .. "." .. menuName -- concatenates the lookup result into fileName.menuName, allowing for two scripts with the same menu name to coexist (so long as they don't share the same filename)
	if customGui[fileName] == nil then
		customGui[fileName] = {}
	end
	if customGui[fileName][menuName] ~= nil then
		error("initStatic_MB: Tried to load a _MessageBox with name " .. menuName .. ", but it was already there!")
		return false
	end
	customGui[fileName][menuName] = {}
	local menu = {}
	menu.menuType = "_MessageBox"
	menu.label = stringCompiler(argLabel)
	customGui[fileName][menuName] = menu
	serverLog("initStatic_MB: Successfully loaded new _MessageBox " .. menuName)
end

local function initStaticDialog(fileName, menuName, idGui, argLabel, argNote, argDestinations, argHidden)
	if lookup[idGui] ~= nil then
		error("initStaticDialog: Lookup result for ID " .. idGui .. " already exists! Result: " .. lookup[idGui])
	end
	lookup[idGui] = fileName .. "." .. menuName
	if customGui[fileName] == nil then
		customGui[fileName] = {}
	end
	if customGui[fileName][menuName] ~= nil then
		error("initStaticDialog: Tried to load a Dialog with name " .. menuName .. ", but it was already there!")
		return false
	end
	customGui[fileName][menuName] = {}
	local menu = {}
	menu.menuType = "Dialog"
	menu.label = stringCompiler(argLabel)
	menu.note = stringCompiler(argNote)
	menu.hidden = argHidden
	menu.destinations = destinationCompiler(argDestinations)
	customGui[fileName][menuName] = menu
	if argHidden then
		serverLog("initStaticDialog: Successfully loaded new Dialog " .. menuName .. ", initialized as PasswordDialog")
	else
		serverLog("initStaticDialog: Successfully loaded new Dialog " .. menuName .. ", initialized as InputDialog")
	end
end

local function initStaticCMBMenu(fileName, menuName, idGui, argLabel, argButtons, argDestinations)
	if lookup[idGui] ~= nil then
		error("initStaticCMBMenu: Lookup result for ID " .. idGui .. " already exists! Result: " .. lookup[idGui])
	end
	lookup[idGui] = fileName .. "." .. menuName
	if customGui[fileName] == nil then
		customGui[fileName] = {}
	end
	if customGui[fileName][menuName] ~= nil then
		error("initStaticCMBMenu: Tried to load a CustomMessageBox with name " .. menuName .. ", but it was already there!")
		return false
	end
	customGui[fileName][menuName] = {}
	local menu = {}
	menu.menuType = "CustomMessageBox"
	menu.label = stringCompiler(argLabel)
	-- This allows buttons to either be written as a (un)enumerated table, taking more of the workload off the menu creator and making it easier to see what button corresponds to what destination, or as a preformatted string, taking more of the work off the program or for easy copy+paste of existing menus.
	if type(argButtons) == "string" then
		menu.buttons = argButtons
	else
		local formattedButtonTable = {}
		local strungButtons = ""
		for i, str in pairs(argButtons) do -- Part 2 of allowing you to format buttons the same as destinations - this reformats the resulting table as a proper array to be used by table.concat() (and by 'proper array', I mean 'it makes the keys start from one and iterate from there').
			if tonumber(i) then
				i = tonumber(i)
			end
			serverDebug("	- Button " .. i .. ", slottype " .. type(i) ..  ", with content " .. str .. " inserted to table")
			formattedButtonTable[i] = str
		end
		local firstValueIndex = 0
		while formattedButtonTable[firstValueIndex] == nil do 
			firstValueIndex = firstValueIndex + 1
		end
		strungButtons = tableConcat(formattedButtonTable,";",firstValueIndex)
		menu.buttons = strungButtons
		serverDebug("	- Buttons strung as \"" .. strungButtons .. "\"")
	end
	menu.destinations = destinationCompiler(argDestinations)
	customGui[fileName][menuName] = menu
	serverLog("initStaticCMBMenu: Successfully loaded new CustomMessageBox " .. menuName)
end

local function initStaticLBMenu(fileName, menuName, idGui, argLabel, argDataSource, argDestinations)
	if lookup[idGui] ~= nil then
		error("initStaticLBMenu: Lookup result for ID " .. idGui .. " already exists! Result: " .. lookup[idGui])
	end
	lookup[idGui] = fileName .. "." .. menuName
	if customGui[fileName] == nil then
		customGui[fileName] = {}
	end
	if customGui[fileName][menuName] ~= nil then
		error("initStaticLBMenu: Tried to load a CustomMessageBox with name " .. menuName .. ", but it was already there!")
		return false
	end
	customGui[fileName][menuName] = {}
	local menu = {}
	menu.menuType = "ListBox"
	menu.label = stringCompiler(argLabel)
	menu.dataSource = load(argDataSource, nil, "t")
	menu.destinations = destinationCompiler(argDestinations)
	customGui[fileName][menuName] = menu
	serverLog("initStaticLBMenu: Successfully loaded new ListBox " .. menuName)
end

-- MENU LOADER --

local loadMenus = function()
	local menuFile = {}
	local loadedMenu = {}
	local fileName = ""
	local fileNumber = 0
	local globalMenuNumber = 0
	for _, source in ipairs(sources) do
		local menuNumber = 0
		fileName = getFileNameNoExtension(source)
		menuFile = jsonLoad(source)
		if menuFile == nil then
			error("Source " .. source .. " could not be loaded! Check formatting.")
		else
			serverDebug("loadMenus: Successfully loaded file " .. fileName)
		end
		for menuName, menu in pairs(menuFile) do
			loadedMenu = menu
			menuType = loadedMenu.menuType
			
			serverDebug("loadMenus: Now attempting to load menu " .. menuName)
			if menuType == "_MessageBox" then
				initStatic_MB(fileName,menuName,loadedMenu.idGui,loadedMenu.label)
			elseif menuType == "Dialog" then
				initStaticDialog(fileName,menuName,loadedMenu.idGui,loadedMenu.label,loadedMenu.note,loadedMenu.destinations,loadedMenu.hidden)
			elseif menuType == "CustomMessageBox" then
				initStaticCMBMenu(fileName,menuName,loadedMenu.idGui,loadedMenu.label,loadedMenu.buttons,loadedMenu.destinations)
			elseif menuType == "ListBox" then
				initStaticLBMenu(fileName,menuName,loadedMenu.idGui,loadedMenu.label,loadedMenu.dataSource,loadedMenu.destinations)
			else
				error("INVALID MENU TYPE IN " .. source .. " MENU " .. menuName)
			end
			menuNumber = menuNumber + 1
		end
		serverLog("loadMenus: Successfully loaded " .. menuNumber .. " menus from file " .. fileName)
		globalMenuNumber = globalMenuNumber + menuNumber
		fileNumber = fileNumber + 1
	end
	serverLog("loadMenus: Successfully loaded " .. globalMenuNumber .. " menus from " .. fileNumber .. " files.")
	return true
end

-- INIT --

function menuManager.initialization()
	if loadMenus() then
		return true
	else
		error("MenuManager.initialization: Failed to load menus from source files! Check sources in MenuManager/base.lua, ensure all menu sources are properly defined and that all menu source files are properly formatted.")
		return false
	end
end

-- GUI HANDLERS --

local function split(str) -- gotta get the filename and the menuname back out of the concatenated lookup so we can actually use it
	local tabledString = {}
	for key in string.gmatch(str, "([^%.]+)") do
		tableInsert(tabledString, key)
	end
	return tabledString[1], tabledString[2]
end

local function grabDynamicResults(pid, menu)
	local label
	local note
	if menu.menuType == "_MessageBox" or menu.menuType == "CustomMessageBox" or menu.menuType == "ListBox" then
		if type(menu.label) == "function" then
			label = menu.label(pid) -- call it
		else
			label = menu.label -- just define it normally
		end
	elseif menu.menuType == "Dialog" then
		if type(menu.label) == "function" then
			label = menu.label(pid)
		else
			label = menu.label
		end
		if type(menu.note) == "function" then
			note = menu.note(pid)
		else
			note = menu.note
		end
	end
	return label, note
end

function menuManager.showMenu(pid, idGui)
	if lookup[idGui] == nil then
		serverWarn("showMenu: Was called, but no menu exists for that idGui lookup!") -- If you get this, a menu or external function that uses showMenu is using a faulty idGui entry, either due to a typo or a menu not being properly loaded.
		return false
	end
	local fileName, menuName = split(lookup[idGui])
	local lookupResult = customGui[fileName][menuName]
	serverDebug("showMenu: Accessing menu " .. fileName .. "." ..  menuName)
	local labelResult, noteResult = grabDynamicResults(pid, lookupResult)
	if lookupResult.menuType == "_MessageBox" then
		serverDebug("showMenu: Showing _MessageBox " ..  menuName)
		return tes3mp.MessageBox(pid, idGui, labelResult)
	elseif lookupResult.menuType == "Dialog" then
		if lookupResult.hidden == true then
			serverDebug("showMenu: Showing PasswordDialog " ..  menuName)
			return tes3mp.PasswordDialog(pid, idGui, labelResult, noteResult)
		else
			serverDebug("showMenu: Showing InputDialog " ..  menuName)
			return tes3mp.InputDialog(pid, idGui, labelResult, noteResult)
		end
	elseif lookupResult.menuType == "CustomMessageBox" then
		serverDebug("showMenu: Showing CustomMessageBox " ..  menuName)
		return tes3mp.CustomMessageBox(pid, idGui, labelResult, lookupResult.buttons)
	elseif lookupResult.menuType == "ListBox" then
		serverDebug("showMenu: Showing ListBox " ..  menuName)
		return tes3mp.ListBox(pid, idGui, labelResult, lookupResult.dataSource())
	else
		error("Lookup result for " .. lookupResult .. " exists, but no type is stated!") -- You should never get this message unless you have edited this script. Menu types are determined when the menu is first loaded.
	end
end

function menuManager.GUIActionHandler(pid, idGui, data)
	if lookup[idGui] == nil then
		serverDebug("GUIActionHandler: " .. idGui .. " not listed in lookup return keys. Return dropped.")
		return
	end
	local fileName, menuName = split(lookup[idGui])
	local lookupResult = customGui[fileName][menuName]
	local dataNumber
	if tonumber(data) then
		serverDebug("GUIActionHandler: Data was numbered, number is " .. tonumber(data))
		dataNumber = tonumber(data)
	end
	for i, destination in pairs(lookupResult.destinations) do
		serverDebug("GUIActionHandler: Destination found in slot " .. i .. " is " .. tostring(destination) .. " and type of index is " .. type(i))
	end
	if dataNumber ~= nil then
		serverDebug("GUIActionHandler: dataNumber was found to not be nil, seen as " .. dataNumber)
		if customGui[fileName][menuName]["destinations"][dataNumber] ~= nil then
			serverDebug("GUIActionHandler: Supposed to return destination " .. dataNumber .. " to pid " .. pid)
			return lookupResult.destinations[dataNumber](pid)
		elseif customGui[fileName][menuName]["destinations"]["any"] ~= nil then
			serverDebug("GUIActionHandler: dataNumber was " .. dataNumber .. ", supposed to return destination \"any\" to pid " .. pid)
			return lookupResult.destinations.any(pid, dataNumber)
		else
			serverDebug("Datanumber was not nil, but " .. fileName.."."..menuName .. " has no entry["..dataNumber.."], nor an \"any\" entry. Possible control flow attempt?")
			return false
		end
	elseif lookupResult.destinations.any ~= nil then
		serverDebug("GUIActionHandler: data was not a number, returning destination \"any\" to pid " .. pid)
		return lookupResult.destinations.any(pid, data) -- 
	else
		serverWarn("UNDEFINED BEHAVIOR: Invalid menu selection attempted for menu table " .. fileName.."."..menuName)
		return false
	end
end

-- EVENT HANDLER HOOKS --

customEventHooks.registerHandler("OnServerPostInit", function()
	if menuManager.initialization() then
		return
	else
		error("Initialization failed. Exiting...")
	end
end)

customEventHooks.registerHandler("OnGUIAction", function(eventStatus, pid, idGui, data)
	if menuManager.GUIActionHandler(pid, idGui, data) then
		return
	end
end)

return menuManager