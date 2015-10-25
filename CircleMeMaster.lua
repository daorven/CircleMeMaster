-----------------------------------------------------------------------------------------------
-- Client Lua Script for CircleMeMaster
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Apollo"
require "ICCommLib"
require "ICComm"
require "GuildLib"
require "GuildTypeLib"
require "ChatChannelLib"
 
-----------------------------------------------------------------------------------------------
-- CircleMeMaster Module Definition
-----------------------------------------------------------------------------------------------
local CircleMeMaster = {} 

local dbEntryDefault = { 
	name  = "",
	entryType = 1, -- GuildLib.GuildType_Circle or GuildLib.GuildType_Guild
	announce = true,
	pvp   = true,
	pve   = true,
	rp    = true,
	other = true,
	desc  = ""
	}
	
local JSON = Apollo.GetPackage("Lib:dkJSON-2.5").tPackage
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function CircleMeMaster:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
    return o
end

function CircleMeMaster:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		--"SocialPanel",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- CircleMeMaster OnLoad
-----------------------------------------------------------------------------------------------
function CircleMeMaster:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("CircleMeMaster.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function CircleMeMaster:OnSave(eType)
    if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
        return
    end
	return self.dbMasterStorage
end

function CircleMeMaster:OnRestore(eType, tSavedData)

	self.dbMasterStorage = tSavedData
end
-----------------------------------------------------------------------------------------------
-- CircleMeMaster OnDocLoaded
-----------------------------------------------------------------------------------------------
function CircleMeMaster:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MainFormBorder", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
	    self.wndMain:Show(false, true)
		self.wndItemList = self.wndMain:FindChild("MainFormInner"):FindChild("Grid")
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		-- only need to refresh once to trigger the refresh of guild rosters
		Apollo.RegisterSlashCommand("cmm", "OnCircleMeMasterOn", self)
		Apollo.RegisterEventHandler("GuildRoster",           "OnGuildRoster", self)
		Apollo.RegisterEventHandler("GuildMemberChange",     "OnGuildMemberChange", self)
		
		-- Channel Events
		Apollo.RegisterEventHandler("ReceivedMessageEvent","OnGlobalMessageReceived",self)
		self.myTimer = ApolloTimer.Create(1, false, "Connect_Global", self) -- Rejoin if it cannot join channel
		self.myTimer:Start()
		if self.dbMasterStorage == nil then
			self.dbMasterStorage = {}
		end 
		-- Do additional Addon initialization here
	end
end


function CircleMeMaster:DoCircleAnnounce()

end 

function CircleMeMaster:OnListCircleCheck( wndHandler, wndControl, eMouseButton )
	--local cName = wndHandler:FindChild("circleName"):GetText()

	
end

function CircleMeMaster:StoreDBValue( dbName, sName, eType, bPvp, bPve, bRP, bOther, sDesc, bAnnounce )
	local tTemp = {
		name  = sName,
		entryType = eType,
		announce = bAnnounce,
		pvp   = bPvp,
		pve   = bPve,
		rp    = bRP,
		other = bOther,
		desc  = sDesc,
	}
	table.insert( dbName, tTemp )
end 

function CircleMeMaster:CircleExists( sName, del ) -- Return Results: 0 = false, 1 = true, 2 = deleted
	for idx, val in ipairs( self.dbMasterStorage ) do 
		Print("[CMM] Looking for (( "..sName..")) DB Entry is (( "..val.name.." ))")
		if val.name == sName then 
			if del == true then 
				-- we wish to delete this index
				table.remove( self.dbMasterStorage[idx] )
				return 2
			end 
			return 1 
		end 
	end 
	return 0
end 

-----------------------------------------------------------------------------------------------
-- CircleMeMaster Channel Functions
-----------------------------------------------------------------------------------------------

function CircleMeMaster:Connect_Global()
	-- Joins the Global Broadcast/Receiving Channel for Announcements
	if self.myTimer ~= nil then self.myTimer:Stop() end 
	
	if self.CMMGlobal then
		return 
	end 

	self.CMMGlobal = ICCommLib.JoinChannel("CircleMeMaster",ICCommLib.CodeEnumICCommChannelType.Global)
	if not self.CMMGlobal then
		Print("CMMGlobal Not Created, rejoining in 1 second...")
		self.myTimer:Start()
		return 
	end 
	--self.CMMGlobal.IsReady()
	-- we have connected, so lets set up the functions
	self.CMMGlobal:SetJoinResultFunction("OnGlobalChannelJoin", self)
	self.CMMGlobal:SetReceivedMessageFunction("OnGlobalMessageReceived", self) 
end 

function CircleMeMaster:OnGlobalChannelJoin()
	for _,v in pairs( self.dbMasterStorage ) do
		-- Send Message For Each Entry in DB
		self:Send( { action = "insert", payload = v } )
	end 
end 

function LUI_Holdem:Send(tMessage)
	local strMsg = JSON.encode(tMessage)
		if self.game.conn == "ICComm" then
			if not self.gamecom then
				self:ConnectToHost()
		    end

		    self.gamecom:SendMessage(tostring(strMsg))
		end
end

function CircleMeMaster:OnGlobalMessageReceived(channel, strMessage, strSender)
	local strMessage = JSON.decode(strMessage)
	if strMessage.action == "insert" then 
		if self:CircleExists( strMessage.payload.name ) == 1 then return end 
		table.insert(self.dbMasterStorage, payload )
	elseif strMessage.action == "remove" then 
		self:CircleExists( strMessage.payload.name, true )
	end
end 
-----------------------------------------------------------------------------------------------
-- CircleMeMaster Functions
-----------------------------------------------------------------------------------------------

-- Define general functions here
function CircleMeMaster:OnGuildMemberChange( guildCurr )
	guildCurr:RequestMembers() -- this is used to reload the list on changes
end

function CircleMeMaster:OnGuildRoster(guildCurr, strName, nRank, eResult) -- Event from CPP
	if guildCurr == nil then 
		return 
	end
	if guildCurr:GetType() == 3 then return end 
	if guildCurr:GetType() == 4 then return end 
	for _,v in pairs( self.dbMasterStorage ) do 
		 if v.name == guildCurr:GetName() then 
			 --Print("[CMM] - Name (( "..v.name.." )) Exists Already")
			 -- Already Exists
			 return 
		end
	end 
		-- doesn't exist, enter in with defaults
		--   pre-enter 3 important settings for editing later on
		--Print("[CMM] - Adding Entry (( "..guildCurr:GetName().." ))")
		local tTempData = {
			name = guildCurr:GetName(),
			announce = false,
			entryType = guildCurr:GetType(),
			pvp   = true,
			pve   = true,
			rp    = true,
			other = true,
			desc  = ""
		}
		table.insert(self.dbMasterStorage, tTempData)
		tTempData = nil
end

-- on SlashCommand "/cmm"
function CircleMeMaster:OnCircleMeMasterOn(sCmd,sArg)
	if sArg == "" then 
		self.wndMain:Show(true)
		Event_FireGenericEvent("SendVarToRover", "db", self.dbMasterStorage)
	end 
	
	-- List The Circles	
end

---------------------------------------------------------------------------------------------------
-- MainFormBorder Functions
---------------------------------------------------------------------------------------------------

function CircleMeMaster:OnCloseCMM( wndHandler, wndControl, eMouseButton )
	self.wndMain:Show(false)
end

function CircleMeMaster:OnGuildButtonClick( wndHandler, wndControl, eMouseButton )
	self:PopulateListByType( GuildLib.GuildType_Guild, false )
	--Print("[CMM] - Generating List by type (( Guild ))")
end

function CircleMeMaster:OnCircleButtonClick( wndHandler, wndControl, eMouseButton )
	self:PopulateListByType( GuildLib.GuildType_Circle, false )
	--Print("[CMM] - Generating List by type (( Circle ))")
end

function CircleMeMaster:PopulateListByType( eType, bOwner ) -- goes through a db and adds a row to a list
	if self.wndItemList == nil then
		Print("[CMM] - Grid Not Found, Aborting...")
		return 
	end 
	for _,guild in ipairs(GuildLib.GetGuilds()) do
		guild:RequestMembers()
	end
	self.wndItemList:DeleteAll()
	for _, val in pairs(self.dbMasterStorage) do 
		if val.entryType == eType then 
			self:AddListItem( val, bOwner )
		end 
	end 
	
end 

function CircleMeMaster:AddListItem( val, bOwner )
	local iCurrRow = self.wndItemList:AddRow("")
	self.wndItemList:SetCellLuaData(iCurrRow, 1, val)
	self.wndItemList:SetCellText( iCurrRow, 1, string.format("%s",val.name) )
	--self.wndItemList:SetCellText(iCurrRow, 2, tCurr.title)
	--self.wndItemList:SetCellText(iCurrRow, 3, string.format("%s, %s",tCurr.location[1],tCurr.location[2]))
	--self.wndItemList:SetCellText(iCurrRow, 4, tCurr.host)
end 

function CircleMeMaster:OnListItemSelected(wndControl, wndHandler, iRow, iCol,iCurrRow, iCurrCol)
	--Print(iRow)
	self.nSelectedEntry = iRow or self.nSelectedEntry
	self:SetToolTip()
end

function CircleMeMaster:OnCharacterCreated()
	self:Build()
end

function CircleMeMaster:Build()
    self:LeaveAllChannels()
    self:Connect()
	self:JoinGlobalChannel()
end

function CircleMeMaster:OnListToggleClick( wndHandler, wndControl, eMouseButton )
	local tWnd = self.wndMain:FindChild("MainFormInner"):FindChild("ListWindow")
	tWnd:Show( not tWnd:IsShown() )
end

function CircleMeMaster:OnSaveCircleCfgClick( wndHandler, wndControl, eMouseButton )
	local curWnd = self.wndMain:FindChild("circleConfigWindow")
	local sCircleName = curWnd:FindChild("cNameWnd"):FindChild("txtCName"):GetText()
	self.tCircleListDB[sCircleName] = {
		["pvp"] = curWnd:FindChild("PvP"):IsChecked(),
		["pve"] = curWnd:FindChild("PvE"):IsChecked(),
		["rp"] = curWnd:FindChild("RP"):IsChecked(),
		["other"] = curWnd:FindChild("Other"):IsChecked(),
		["description"] = curWnd:FindChild("cfgDesc"):GetText(),
		}
	self.wndMain:FindChild("circleConfigWindow"):Show(false)
	
end


---------------------------------------------------------------------------------------------------
-- CircleEntry Functions
---------------------------------------------------------------------------------------------------
function CircleMeMaster:OnCfgClick( wndHandler, wndControl, eMouseButton )
	local cfgWindow = self.wndMain:FindChild("circleConfigWindow")
	cfgWindow:Show(true)
	local circleName = wndControl:GetData()
	cfgWindow:FindChild("cNameWnd"):FindChild("txtCName"):SetText( circleName.name )
	for _ , data in ipairs(self.tCircleListDB) do 
		if data.name == circleName then 
			-- Correct Name, Load Data
			self:LoadCfg( cfgWindow, circleName.name )
			return 
		end 
	end 
	
	-- We made it this far, and it doesn't exist obviously.
	self:UpdateCfg( circleName, nil )
end

function CircleMeMaster:LoadCfg( tWnd, sCircleName )
	local tData = self.tCircleListDB[sCircleName]
	tWnd:FindChild("PvE"):SetCheck(tData["pve"])
	tWnd:FindChild("PvP"):SetCheck(tData["pvp"])
	tWnd:FindChild("RP"):SetCheck(tData["rp"])
	tWnd:FindChild("Other"):SetCheck(tData["other"])
	tWnd:FindChild("cfgDesc"):SetText( tData["description"] )
	
end 

function CircleMeMaster:UpdateCfg( sCircleName, data )
	if data == nil then 
		-- new entry, just create a blank template
		self.tCircleListDB[sCircleName] = {
			["pvp"] = false,
			["pve"] = false,
			["rp"] = false,
			["other"] = false,
			["description"] = "",
			}
	else
		-- existing entry so assign it.
		self.tCircleListDB[sCircleName] = data
	end 
	return 
end 
-----------------------------------------------------------------------------------------------
-- CircleMeMaster Instance
-----------------------------------------------------------------------------------------------
local CircleMeMasterInst = CircleMeMaster:new()
CircleMeMasterInst:Init()
