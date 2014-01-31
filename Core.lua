----------------------------------------------------------------------------------------
---------------------------------------- DerpEP ----------------------------------------
--	Available commands:																  --
--	/derp boss add <Boss_Ability_Amount>				(add a new ability to track)  --
--	/derp boss list	<> (Boss or all)	  	  (list abilities tracked for that boss)  --
--	/derp boss remove <Boss_Ability>	 	   (removes an ability that was tracked)  --
--	/derp channel <> (guild, raid or self)				   (sets the output channel)  --
--	/derp give <> (commit/reset/undo)				(gives DERP EP stored in memory)  --
--	/derp help										  (lists the commands available)  --
--	/derp mode <> (on/off)					     (on: display+apply;   off: display)  --
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

local defaultDerpersDataBackup = {};

local defaultDerpersData = {
	"Git_Vestige of Pride_Consuming Pride_10",
	"Layonhooves_Vestige of Pride_Consuming Pride_10",
	"Layonhooves_Rook Stonetoe_Corrupted Brew_10",
};

local defaultDerps = {
	"Boss_Spell2_10",
	"Vestige of Pride_Consuming Pride_10",
	"Boss_Spell1_10",
};

local defaultDerpSettings = {
	derpAmount = 0,
	derpMode = "OFF",
	derpDisplay = "SELF",
};

local derpersData = savedDerpersData or defaultDerpersData;
local derpersDataBackup = savedDerpersDataBackup or defaultDerpersDataBackup;
local derps = savedDerps or defaultDerps;
local derpSettings = savedDerpSettings or defaultDerpSettings;

local i = 0;
local derpAmount = derpSettings.derpAmount;
local derpDisplay = derpSettings.derpDisplay; --change to GUILD as default
local derpMode = derpSettings.derpMode;  --ON or OFF (ON: calls EPGP;  OFF: Display only)
local name, addon = ...;
local login = true;

local Derp, Events = CreateFrame("Frame"), {};

LibStub("AceConsole-3.0"):Embed(Derp)
LibStub("AceTimer-3.0"):Embed(Derp)
DerpEP = LibStub("AceAddon-3.0"):NewAddon("DerpEP", "AceTimer-3.0")


--	Command line menu.
local derpCommandTable = {
["mode"] = {
	["on"] = function()
		derpMode = "ON"
		print("DerpEP will be applyed.")
	end,
	["off"] = function()
		derpMode = "OFF"
		print("DerpEP will only be displayed.")
	end,
	["help"] = "Available: on, off, help (on: EPGP triggered; off: display only mode)"
},
["boss"] = {
	["add"] = function(parameters)
		bName, sName, amount = string.split("_", parameters)
		addNewDerp(bName,sName,amount)
	end,
	["list"] = function(bossName)
		if bossName == "all" then
			listDerps()
		else
			listBossDerps(bossName)
		end
	end,
	["remove"] = function(parameters)
		bName, sName, _ = string.split("_", parameters)
		removeDerp(bName,sName)
	end,
	["help"] = "Available: add, list, remove, help \n /derp boss add BossName_Ability_Amount \n /derp boss list BossName (or /derp list all) \n /derp boss remove BossName_SpellName"
},
["give"] = {
	["commit"] = function()
		giveDerp()
	end,
	["reset"] = function()
		resetDerpers()
	end,
	["undo"] = function()
		undoDerp()
	end,
	["help"] = "Available: commit, reset, undo, help \n /derp give commit (gives derp then deletes the saved derps) \n /derp give reset (deletes the player derps) \n /derp give undo (restores the EP removed and the saved derps data)"
},
["channel"] = {
	["guild"] = function()
		derpDisplay = "GUILD"
		print("Display channel set to Guild.")
	end,
	["raid"] = function()
		derpDisplay = "RAID"
		print("Display set to Raid.")
	end,
	["self"] = function()
		derpDisplay = "SELF"
		print("Display set to Self.")
	end,
	["show"] = function()
	print ("Display set to: " .. derpDisplay)
	end,
	["help"] = "channel options: guild, raid, self, show, help"
	},
["help"] = "Derp commands: boss, channel, give, mode, help. \n Ex: /derp add Immerseus_Swirl_10 \n /derp boss list all"
}


--	Command line handler.
local function dispatchCommand(message, commandTable)
	local command, parameters = string.split(" ", message, 2)
	local entry = commandTable[command:lower()]
	local which = type(entry)
	if which == "function" then
		entry(parameters)
	elseif which == "table" then
		dispatchCommand(parameters or "", entry)
	elseif which == "string" then
		print(entry)
	elseif message ~= "help" then
	dispatchCommand("help", commandTable)
	end
end


--	Command line registration.
SLASH_DERP1 = "/derp"
SlashCmdList["DERP"] = function(message)
	dispatchCommand(message, derpCommandTable)
end


--	Initialisation on load registering managed events.
function Derp:Initialize()
	print("DerpEP: Welcome to Derpville. Please enjoy your stay!")
	Derp:RegisterEvent("ADDON_LOADED");
	Derp:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	Derp:RegisterEvent("PLAYER_LOGIN");
	Derp:RegisterEvent("PLAYER_LOGOUT");
end


--	Adds a new derp to the boss table or replaces an existing derp with a new derp amount value
function addNewDerp(sourceName,spellName,derpAmount)
	local newDerp = sourceName .. "_" .. spellName
	local newDerpFull = newDerp .. "_" .. derpAmount
	newDerp = strlower(newDerp)
	local bossExists = false
	local bossName = "default"
	local spellName = "default"
	local derpAmt = "default"
	local index = 0
	
	for i, v in ipairs(derps) do
		local bName, sName, amount = string.split("_", v)
		local tempKey = bName .. "_" .. sName
		tempKey = strlower(tempKey)
		print("Derps:" .. derps[i])
		if tempKey == newDerp then
			bossExists = true
			index = i
			bossName = bName
			spellName = sName
			derpAmt = amount
		end
	end
	if bossExists then
		print("The entry " .. sourceName .. "_" .. spellName .. " that had a derp value of " .. derpAmt .. " was changed to: " .. newDerpFull .. ".")
		derps[index] = newDerpFull
	else
		print("The entry " .. newDerpFull .. " was added.")
		table.insert(derps, newDerpFull)
	end
	table.sort(derps)
end


--	Removes a derp for a boss
function removeDerp(sourceName, spellName)
	local key = sourceName .. "_" .. spellName
	local removeBool = false
	local index = 0
	for i, v in ipairs(derps) do
		local bossName, sName, _ = string.split("_", v)
		local tempKey = bossName .. "_" .. sName
		if tempKey == key then
			removeBool = true
			index = i
			print("Found corresponding derp to remove:" .. tempKey)
		end
	end
	if removeBool then
	 	table.remove(derps, index)
		print("The entry " .. key .. " was removed.")
	end
end


--	Outputs derp list for all the bosses.
function listDerps()
	table.sort(derps)
	for i, v in pairs (derps) do
		bName, sName, amount = string.split("_", v)
		local output = bName .. " " .. sName .. " " .. amount
		displayDispatch(output)
	end
end


--	Outputs the list of players with their assigned derp EP
function listDerpers()
	for i, v in ipairs (derpersData) do
		pName, bName, sName, amount = string.split("_", v)
		local output = pName .. " " .. bName .. " " .. sName .. " " .. amount
		displayDispatch(output)
	end
end


--	Resets the list of players with derp EP
function resetDerpers()
	for i, v in ipairs (derpersData) do
		if derpersDataBackup[i] == nil then
			print("derpersDataBackup is empty")
			table.insert(derpersDataBackup, derpersData[i])
			print(i)
		end
	end
	for i, v in ipairs (derpersData) do
		print(i .. " " .. "Removing: " .. derpersData[i])
		derpersData[i] = nil
	end
	printDerpersData()
	printDerpersDataBackup()
end

function printDerpersData()
	print("***** DerpersData *****")
	for i, v in ipairs (derpersData) do
		print (i .. ". " .. derpersData[i])
	end
end

function printDerpersDataBackup()
	print("***** DerpersDataBackup *****")
	for i, v in ipairs (derpersDataBackup) do
		print (i .. ". " ..derpersDataBackup[i])
	end
end


--	Outputs derp list for a specific boss.
function listBossDerps(bossName)
	table.sort(derps)
	for i, v in ipairs (derps) do
		bName, sName, amount = string.split("_", v)
		if bName == bossName then
			displayDispatch(v)
		end
	end
end


--	Tests if the player has already failed to the boss ability.
function hasAlreadyDerped(derpersData, destName, sourceName, spellName)
	local hadDerped = false
	local key = destName .. "_" .. sourceName .. "_" .. spellName
	for _, v in pairs(derpersData) do
		pName, bossName, sName, amount = string.split("_", v)
		tempKey = pName .. "_" .. bossName .. "_" .. sName
		if tempKey == key then
			hadDerped = true
		end
	end
	return hadDerped
end


--	Adds derpAmount to a player that has already failed on the same boss ability.
function addDerp(derpersData, destName, sourceName, spellName, derpAmount)
	local key = destName .. "_" .. sourceName .. "_" .. spellName
	for i, v in ipairs(derpersData) do
		pName, bossName, sName, amount = string.split("_", v)
		local tempKey = pName .. "_" .. bossName .. "_" .. sName
		if tempKey == key then
			print("Derp before update: " .. v)
			amount = amount + derpAmount
			derpersData[i] = pName .. "_" .. bossName .. "_" .. sName .. "_" .. amount
			print("Updated Derp: " .. derpersData[i])
		end
	end
	table.sort(derpersData)
end


--	Outputs derpEP of players saved and backs up the data for a possible undo.
function DerpEP:derpDump()
	if derpersData[1] ~=nil then
		local pName, bossName, sName, amount = string.split("_", derpersData[1])
		amount = amount * -1
		displayDispatch(pName .. ", Derp-" .. sName .. ", " .. amount)
		table.insert(derpersDataBackup, derpersData[1])
		table.remove(derpersData, 1)
		--table.sort(derpersData)
	end
	--OUTPUT to guild chat
	--SendChatMessage(pName .. ", Derp-" .. sName .. ", " .. amount .. ")", GUILD)
end


--	Gives derpEP to players saved and backs up the data for a possible undo.
function DerpEP:EPGPDump()
	if derpersDataBackup[1] ~=nil then
		local pName, bossName, sName, amount = string.split("_", derpersDataBackup[1])
		displayDispatch(pName .. ", Derp-" .. sName .. ", " .. amount)
		table.insert(derpersData, derpersDataBackup[1])
		table.remove(derpersDataBackup, 1)
		--table.sort(derpersDataBackup)
	end
	--print("EPGP:IncEPBy(" .. pName .. ", Derp-" .. sName .. ", " .. amount .. ")")
	--EPGP:IncEPBy(pName, "Derp-" .. sName, amount)
end


--	Restores derpEP to the state before a call of derpDump().
function DerpEP:derpRestore()
	if derpersDataBackup[1] ~=nil then
		local pName, bossName, sName, amount = string.split("_", derpersDataBackup[1])
		displayDispatch(pName .. ", Derp-" .. sName .. ", " .. amount)
		table.insert(derpersData, derpersDataBackup[1])
		table.remove(derpersDataBackup, 1)
		--table.sort(derpersDataBackup)
	end
	--OUTPUT to guild chat
	--SendChatMessage(pName .. ", Derp-" .. sName .. ", " .. amount .. ")", GUILD)
end


--	Restores derpEP to the state before a call of EPGPDump().
function DerpEP:EPGPRestore()
	if derpersData[1] ~=nil then
		local pName, bossName, sName, amount = string.split("_", derpersData[1])
		amount = amount * -1
		displayDispatch("EPGP:IncEPBy(" .. pName .. ", Derp-" .. sName .. ", " .. amount .. ")")
		table.insert(derpersDataBackup, derpersData[1])
		table.remove(derpersData, 1)
		--table.sort(derpersData)
	end
	--print("EPGP:IncEPBy(" .. pName .. ", Derp-" .. sName .. ", " .. amount .. ")")
	--EPGP:IncEPBy(pName, "Derp-" .. sName, amount)
end


--	Applies the derpEP saved so far through EPGP on a delay timer for EPGP to digest it.
function giveDerp()
local delay = 0
	for i, v in ipairs(derpersData) do
		if derpMode == "ON" then
			DerpEP.dumpTimer = DerpEP:ScheduleTimer("EPGPDump", delay)
		elseif derpMode == "OFF" then
			DerpEP.dumpTimer = DerpEP:ScheduleTimer("derpDump", delay)
		end
	delay = delay + 0.5
	end
end


--	Cancels the derpEP saved so far through EPGP on a delay timer for EPGP to digest it.
function undoDerp()
local delay = 0
	for _, v in pairs(derpersDataBackup) do
		pName, bossName, sName, amount = string.split("_", v)
		if derpMode == "ON" then
			DerpEP.dumpTimer = DerpEP:ScheduleTimer("EPGPRestore", delay)
		elseif derpMode == "OFF" then
			DerpEP.dumpTimer = DerpEP:ScheduleTimer("derpRestore", delay)
		end
	delay = delay + 0.5
	end
end


--	Changes the display assigned channel for outputs.
function displayDispatch(message)
	if derpDisplay == "SELF" then
		print(message)
	elseif derpDisplay == "GUILD" then
		SendChatMessage(message, GUILD)
	elseif derpDisplay == "RAID" then
		SendChatMessage(message, RAID)
	else
		print(message)
	end
end


--	Manages derp event couples (new or repetition).
function newDerper(derpersData, destName, sourceName, spellName, derpAmount, destFlags)
	local typeFlags = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_MASK)
	local isPlayer = typeFlags == COMBATLOG_OBJECT_TYPE_PLAYER
	if not hasAlreadyDerped(derpersData, destName, sourceName, spellName) and isPlayer then
		print("Adding new derper.")
		newEntry = destName .. "_" .. sourceName .. "_" .. spellName .. "_" .. derpAmount
		table.insert(derpersData, newEntry)
		print("Added " .. newEntry .. " to the current table.")
	elseif hasAlreadyDerped(derpersData, destName, sourceName, spellName) and isPlayer then
		addDerp(derpersData, destName, sourceName, spellName, derpAmount)
	end
end


--	Handler to manage data load upon a new session.
function Events:ADDON_LOADED(...)
	arg1 = ...
    if(login and arg1 == "DerpEP") then
        login = nil
		derps = savedDerps
		derpersData = savedDerpersData
		derpersDataBackup = savedDerpersDataBackup
		derpSettings = savedDerpSettings
        Derp:UnregisterEvent("ADDON_LOADED")
        Derp:UnregisterEvent("PLAYER_LOGIN")
    end
end


--	Handler
function Events:PLAYER_LOGIN(...)
    if login then
        login = nil
        Derp:UnregisterEvent("ADDON_LOADED")
        Derp:UnregisterEvent("PLAYER_LOGIN")
    end
end


--	Handler to manage data backup as a player logs out or /reload.
function Events:PLAYER_LOGOUT(...)
    if not login then
        login = true
		savedDerps = derps
		savedDerpersData = derpersData
		savedDerpersDataBackup = derpersDataBackup
		savedDerpSettings = derpSettings
        Derp:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end


--	Handler to manage combat events.
function Events:COMBAT_LOG_EVENT_UNFILTERED(...)
	local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, amount, spellName = ...;

	local typeFlags = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_MASK)
	local isPlayer = typeFlags == COMBATLOG_OBJECT_TYPE_PLAYER
	local key = ""

	if event ~= "SPELL_DAMAGE" and event ~= "SPELL_PERIODIC_DAMAGE" or not isPlayer then return end
	if sourceName ~= nil and spellName ~= nil then key = sourceName .. "_" .. spellName else return end

	for _, v in pairs(derps) do
		bossName, sName, amount = string.split("_", v)
		local tempKey = bossName .. "_" .. sName
		if tempKey == key then
			--listDerps()	--remove
			listDerpers()	--remove
			newDerper(derpersData, destName, sourceName, spellName, amount, destFlags)
			--EPGP:IncEPBy(destName, "Derp-" .. spellName, derpAmount)
			--listDerps()	--remove
			--listDerpers()	--remove
			break
		end
	end
end


--	Handler to dispatch events management.
Derp:SetScript("OnEvent", function(self, event, ...)--function(self, event, timeStamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, ...)
	Events[event](self, ...)
end)


Derp:Initialize()
