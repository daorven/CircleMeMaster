-----------------------------------------------------------------------------------------------
-- Client Lua Script for CircleMeMaster
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Apollo"
require "ChatSystemLib"
require "GuildLib"
require "GuildTypeLib"
require "ChatChannelLib"
 
-----------------------------------------------------------------------------------------------
-- CircleMeMaster Module Definition
-----------------------------------------------------------------------------------------------
local CircleMeMaster = {} 
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

    return 1
end

function CircleMeMaster:OnRestore(eType, tSavedData)
    if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
        return
    end

    if tSavedData ~= nil and tSavedData ~= "" then
        
    end
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
		self.circleList = {}
		self.circleAnnounceList = {}
		self.tCircleListDB = {}
	    self.wndMain:Show(false, true)
		self.wndMain:FindChild("MainFormInner"):FindChild("ListWindow"):Show(false, true)
		self.wndMain:FindChild("circleConfigWindow"):Show(false, true)
		
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		-- only need to refresh once to trigger the refresh of guild rosters
		Apollo.RegisterSlashCommand("cmm", "OnCircleMeMasterOn", self)
		Apollo.RegisterEventHandler("GuildRoster",           "OnGuildRoster", self)
		Apollo.RegisterEventHandler("GuildMemberChange",     "OnGuildMemberChange", self)
		Apollo.RegisterTimerHandler("CircleMeMaster_JoinGlobal", "JoinGlobalChannel", self)
		
		-- Channel Events
		Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
		Apollo.RegisterEventHandler("ReceivedMessageEvent","OnChannelMessageReceive",self)
		
		for _,guild in ipairs(GuildLib.GetGuilds()) do
			guild:RequestMembers()
		end

		-- Do additional Addon initialization here
	end
end

-- Channel Functions 
function CircleMeMaster:Connect()
    if not self.global then
        self.global = ICCommLib.JoinChannel("CircleMeMaster", ICCommLib.CodeEnumICCommChannelType.Global)
    end

    if self.global:IsReady() then
        self.global:SetReceivedMessageFunction("OnICCommMessageReceived", self)
        self.global:SetSendMessageResultFunction("OnICCommSendMessageResult", self)
		self:DoCircleAnnounce()
    else
    	Apollo.CreateTimer("GlobalConnect", 3, false)
    end
end 

function CircleMeMaster:JoinGlobalChannel()
    local chatActive = false

    for idx, channelCurrent in ipairs(ChatSystemLib.GetChannels()) do
    	if channelCurrent:GetName() == "CircleMeMaster" then
    		chatActive = true
    		self.global = channelCurrent
    	end
    end

    if not chatActive then
    	ChatSystemLib.JoinChannel("CircleMeMaster")
    end

    if self.global then
    	self:HideChannel(self.global:GetUniqueId())
    else
    	Apollo.CreateTimer("CircleMeMaster_JoinGlobal", 1, false)
    end
end

function CircleMeMaster:OnGlobalMessage(message)
	if not message or not message.action then
		return
	end

	if message.action == "insert" then
		self:AddCircle(message)
	elseif message.action == "delete" then
		self:RemoveCircle(message)
	end
end

function CircleMeMaster:AddCircle( message ) -- Add the Circle To The List
  -- Loop Through List Names
  -- If The Name Exists, return
  -- If The name Doesn't Exist, add it 
  Print("Got a message to [ "..message.action.." ] a circle. Should be Add.")
end 

function CircleMeMaster:RemoveCircle( message ) -- Remove Circle From The List
	-- Loop Through List Names 
	-- If The Name Exists, Delete It 
	-- If Not, return
	 Print("Got a message to [ "..message.action.." ] a circle. Should be Remove.")
end 

function CircleMeMaster:OnICCommMessageReceived(channel, strMessage, idMessage)
	local message = JSON.decode(strMessage)

	if type(message) ~= "table" then
		return
	end

	if not self.global then
		return
	end

	self:OnGlobalMessage(message)
end

function CircleMeMaster:HideChannel(id)
    if not aChatLog then
        return
    end

    if not aChatLog.tChatWindows then
        return
    end

	for key, wnd in pairs(aChatLog.tChatWindows) do
    	local tData = wnd:GetData()

    	if tData.tViewedChannels and tData.tViewedChannels[id] then
    		tData.tViewedChannels[id] = false

    		aChatLog:HelperRemoveChannelFromAll(id)
    	end
    end
end

function CircleMeMaster:OnChannelMessageReceive(channel, strMessage, idMessage)
	if channel ~= self.global then return end 
	if strMessage ~= nil then 
		--Print("Message received: ".. strMessage)
	end
	
end

function CircleMeMaster:Send(tMessage,isTable)
	local strMsg = JSON.encode(tMessage)
	if isTable == true then
		if string.len(tostring(strMsg)) > 450 then
		   	--self:SendSplitMessage(tMessage,isTable)
			self.global:Send(tostring(strMsg))
		else
			self.global:Send(tostring(strMsg))
		end
	end 
end 

function CircleMeMaster:DoCircleAnnounce()
	Print("Circle Announce")
	for _,v in ipairs(self.circleAnnounceList) do
		--TODO: Get Description and Role by circle according to value of 'v'
		--local tempData = GetDataForCircle(v)
		local role = "1,2,3,4" --tempData[1]
		local desc = "Test Description" --tempData[2]
		local tMessage = {
			action = "insert",
			channel = v,
			pvp = true,
			pve = false,
			rp = false,
			other = false,
			description = desc,
		}
		self.global:Post(tMessage)
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
	if guildCurr:GetType() ~= GuildLib.GuildType_Circle then
		return
	end
	for _,v in pairs(self.circleList) do
		if v == guildCurr:GetName() then
			--Print("Already Added To Circle List "..#self.circleList)
			return
		end
	end
	table.insert(self.circleList, guildCurr:GetName())
end

function CircleMeMaster:OnTimer()
	if self.tWndList == nil then return end 
	-- Get List of Checked Circles
	for _,v in ipairs(self.tWndList:GetChildren()) do 
		curChild = v:FindChild("circleName")
		curChildChk = v:FindChild("chkListCircle")
		--Print("Child: " .. curChild:GetText())
		if curChildChk:IsChecked() then 
			--Print("We Will Announce This Circle")
			if #self.circleAnnounceList > 0 then 
				for _,k in pairs(self.circleAnnounceList) do
					if k == v:FindChild("circleName"):GetText() then
						--Print("Already Added To Circle Announce List [ "..#self.circleList.." ]")
					else 
						--Print("Added "..curChild:GetText().." to Announce List")
						table.insert(self.circleAnnounceList,curChild:GetText())				
					end
				end
			else
				--Print("List Empty, Added: " .. curChild:GetText().." to Announce List")
				table.insert(self.circleAnnounceList,curChild:GetText())
			end
		end 
	end 
	
	
end 

-- on SlashCommand "/cmm"
function CircleMeMaster:OnCircleMeMasterOn(sCmd,sArg)
	if sArg == "" then 
		self.wndMain:Show(true)
	end 
	
	-- List The Circles
	self:ListCircles()
	
end

---------------------------------------------------------------------------------------------------
-- MainFormBorder Functions
---------------------------------------------------------------------------------------------------

function CircleMeMaster:OnCloseCMM( wndHandler, wndControl, eMouseButton )
	self.wndMain:Show(false)
end

function CircleMeMaster:ListCircles()
	-- Set a var for the window we'll be working with
	self.tWndList = self.wndMain:FindChild("MainFormInner"):FindChild("cList")
	-- Clear Existing List
	--self.tWndList:DestroyChildren()
	-- Populate by how many are in our Circle List Table
	--Print("Circles To Add: [ "..#self.circleList.." ]")
	for i=1,#self.circleList do 
		--Print("Working with: "..self.circleList[i])
		curWnd = Apollo.LoadForm(self.xmlDoc, "CircleEntry", self.tWndList, self)
		curChildCfgBtn = curWnd:FindChild("btnCfg")
		curChildCfgBtn:SetData( { ["name"] = self.circleList[i] } )
		curWnd:Show(true)
		
		if curWnd == nil then 
			--Print("Could Not Load Circle Entry")
			return 
		end 
		curWnd:FindChild("circleName"):SetText(self.circleList[i])
		
	end 
	--self.tWndList:ArrangeChildrenVert()
	
end 	
function CircleMeMaster:OnCharacterCreated()
	self:Build()
end

function CircleMeMaster:Build()
    self:LeaveAllChannels()
    self:Connect()
	self:JoinGlobalChannel()
end

function CircleMeMaster:LeaveAllChannels()
    for idx, channelCurrent in ipairs(ChatSystemLib.GetChannels()) do
        if string.find(channelCurrent:GetName(),"CircleMeMaster") then
            channelCurrent:Leave()
        end
    end
end

function CircleMeMaster:Extend(...)
    local args = {...}
    for i = 2, #args do
        for key, value in pairs(args[i]) do
            args[1][key] = value
        end
    end
    return args[1]
end

function CircleMeMaster:OnListToggleClick( wndHandler, wndControl, eMouseButton )
	local tWnd = self.wndMain:FindChild("MainFormInner"):FindChild("ListWindow")
	tWnd:Show( not tWnd:IsShown() )
end

function CircleMeMaster:OnSaveCircleCfgClick( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("circleConfigWindow"):Show(false)
	-- TODO Save Data To DB :O
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
			["description"] = "Circle Description",
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