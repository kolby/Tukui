local ElvCF = ElvCF
local ElvDB = ElvDB

--Base code by Dawn (dNameplates)
if not ElvCF["nameplate"].enable == true then return end

local TEXTURE = ElvCF["media"].normTex
local FONT = ElvCF["media"].font
local FONTSIZE = ElvCF["general"].fontscale*0.9
local FONTFLAG = "THINOUTLINE"
local hpHeight = 12
local hpWidth = 110
local iconSize = 25		--Size of all Icons, RaidIcon/ClassIcon/Castbar Icon
local cbHeight = 5
local cbWidth = 110
local blankTex = ElvCF["media"].blank
local OVERLAY = [=[Interface\TargetingFrame\UI-TargetingFrame-Flash]=]
local numChildren = -1
local frames = {}
local noscalemult = ElvDB.mult * ElvCF["general"].uiscale

--Change defaults if we are showing health text or not
if ElvCF["nameplate"].showhealth ~= true then
	hpHeight = 7
	iconSize = 20
end

local NamePlates = CreateFrame("Frame", nil, UIParent)
NamePlates:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
SetCVar("bloatthreat", 0) -- stop resizing nameplate according to threat level.
SetCVar("bloattest", 0)
if ElvCF["nameplate"].overlap == true then
	SetCVar("spreadnameplates", "0")
else
	SetCVar("spreadnameplates", "1")
end

local function QueueObject(parent, object)
	parent.queue = parent.queue or {}
	parent.queue[object] = true
end

local function HideObjects(parent)
	for object in pairs(parent.queue) do
		if(object:GetObjectType() == 'Texture') then
			object:SetTexture(nil)
			object.SetTexture = ElvDB.dummy
		elseif (object:GetObjectType() == 'FontString') then
			object.ClearAllPoints = ElvDB.dummy
			object.SetFont = ElvDB.dummy
			object.SetPoint = ElvDB.dummy
			object:Hide()
			object.Show = ElvDB.dummy
			object.SetText = ElvDB.dummy
			object.SetShadowOffset = ElvDB.dummy
		else
			object:Hide()
			object.Show = ElvDB.dummy
		end
	end
end

local function CheckBlacklist(frame, ...)
	if PlateBlacklist[frame.name:GetText()] or (ElvDB.level ~= 1 and frame.oldlevel:GetText() == tostring(1)) then
		frame:SetScript("OnUpdate", function() end)
		frame.hp:Hide()
		frame.cb:Hide()
		frame.overlay:Hide()
		frame.oldlevel:Hide()
	end
end

local function HideDrunkenText(frame, ...)
	if frame and frame.oldlevel and frame.oldlevel:IsShown() then
		frame.oldlevel:Hide()
	end
end

local function ForEachPlate(functionToRun, ...)
	for frame in pairs(frames) do
		if frame:IsShown() then
			functionToRun(frame, ...)
		end
	end
end

local goodR, goodG, goodB = unpack(ElvCF["nameplate"].goodcolor)
local badR, badG, badB = unpack(ElvCF["nameplate"].badcolor)
local transitionR, transitionG, transitionB = unpack(ElvCF["nameplate"].transitioncolor)
local function UpdateThreat(frame, elapsed)
	frame.hp:Show()
	
	if ElvCF["nameplate"].enhancethreat ~= true then
		if(frame.region:IsShown()) then
			local _, val = frame.region:GetVertexColor()
			if(val > 0.7) then
				frame.healthborder_tex1:SetTexture(transitionR, transitionG, transitionB)
				frame.healthborder_tex2:SetTexture(transitionR, transitionG, transitionB)
				frame.healthborder_tex3:SetTexture(transitionR, transitionG, transitionB)
				frame.healthborder_tex4:SetTexture(transitionR, transitionG, transitionB)
			else
				frame.healthborder_tex1:SetTexture(badR, badG, badB)
				frame.healthborder_tex2:SetTexture(badR, badG, badB)
				frame.healthborder_tex3:SetTexture(badR, badG, badB)
				frame.healthborder_tex4:SetTexture(badR, badG, badB)
			end
		else
			frame.healthborder_tex1:SetTexture(0.3, 0.3, 0.3)
			frame.healthborder_tex2:SetTexture(0.3, 0.3, 0.3)
			frame.healthborder_tex3:SetTexture(0.3, 0.3, 0.3)
			frame.healthborder_tex4:SetTexture(0.3, 0.3, 0.3)
		end
	else
		if not frame.region:IsShown() then
			if InCombatLockdown() and frame.hasclass ~= true and frame.isFriendly ~= true then
				--No Threat
				if ElvDB.Role == "Tank" then
					frame.hp:SetStatusBarColor(badR, badG, badB)
					frame.hp.hpbg:SetTexture(badR, badG, badB, 0.25)
				else
					frame.hp:SetStatusBarColor(goodR, goodG, goodB)
					frame.hp.hpbg:SetTexture(goodR, goodG, goodB, 0.25)
				end		
			else
				--Set colors to their original, not in combat
				frame.hp:SetStatusBarColor(frame.hp.rcolor, frame.hp.gcolor, frame.hp.bcolor)
				frame.hp.hpbg:SetTexture(frame.hp.rcolor, frame.hp.gcolor, frame.hp.bcolor, 0.25)
			end
		else
			--Ok we either have threat or we're losing/gaining it
			local r, g, b = frame.region:GetVertexColor()
			if g + b == 0 then
				--Have Threat
				if ElvDB.Role == "Tank" then
					frame.hp:SetStatusBarColor(goodR, goodG, goodB)
					frame.hp.hpbg:SetTexture(goodR, goodG, goodB, 0.25)
				else
					frame.hp:SetStatusBarColor(badR, badG, badB)
					frame.hp.hpbg:SetTexture(badR, badG, badB, 0.25)
				end
			else
				--Losing/Gaining Threat
				frame.hp:SetStatusBarColor(transitionR, transitionG, transitionB)	
				frame.hp.hpbg:SetTexture(transitionR, transitionG, transitionB, 0.25)
			end
		end
	end
	
	-- show current health value
	local minHealth, maxHealth = frame.healthOriginal:GetMinMaxValues()
	local valueHealth = frame.healthOriginal:GetValue()
	local d =(valueHealth/maxHealth)*100
	
	if ElvCF["nameplate"].showhealth == true then
		frame.hp.value:SetText(ElvDB.ShortValue(valueHealth).." - "..(string.format("%d%%", math.floor((valueHealth/maxHealth)*100))))
	end
		
	--Change frame style if the frame is our target or not
	if UnitName("target") == frame.name:GetText() and frame:GetAlpha() == 1 then
		--Targetted Unit
		frame.name:SetTextColor(1, 1, 0)
	else
		--Not Targetted
		frame.name:SetTextColor(1, 1, 1)
	end
	
	--Setup frame shadow to change depending on enemy players health, also setup targetted unit to have white shadow
	if frame.hasclass == true or frame.isFriendly == true then
		if(d <= 50 and d >= 20) then
			frame.healthborder_tex1:SetTexture(1, 1, 0)
			frame.healthborder_tex2:SetTexture(1, 1, 0)
			frame.healthborder_tex3:SetTexture(1, 1, 0)
			frame.healthborder_tex4:SetTexture(1, 1, 0)
		elseif(d < 20) then
			frame.healthborder_tex1:SetTexture(1, 0, 0)
			frame.healthborder_tex2:SetTexture(1, 0, 0)
			frame.healthborder_tex3:SetTexture(1, 0, 0)
			frame.healthborder_tex4:SetTexture(1, 0, 0)
		else
			frame.healthborder_tex1:SetTexture(0.3, 0.3, 0.3)
			frame.healthborder_tex2:SetTexture(0.3, 0.3, 0.3)
			frame.healthborder_tex3:SetTexture(0.3, 0.3, 0.3)
			frame.healthborder_tex4:SetTexture(0.3, 0.3, 0.3)
		end
	elseif (frame.hasclass ~= true and frame.isFriendly ~= true) and ElvCF["nameplate"].enhancethreat == true then
		frame.healthborder_tex1:SetTexture(0.3, 0.3, 0.3)
		frame.healthborder_tex2:SetTexture(0.3, 0.3, 0.3)
		frame.healthborder_tex3:SetTexture(0.3, 0.3, 0.3)
		frame.healthborder_tex4:SetTexture(0.3, 0.3, 0.3)
	end
end

local function Colorize(frame)
	local r,g,b = frame.hp:GetStatusBarColor()
	if frame.hasclass == true then frame.isFriendly = false return end
	
	if g+b == 0 then -- hostile
		r,g,b = unpack(ElvDB.oUF_colors.reaction[1])
		frame.isFriendly = false
	elseif r+b == 0 then -- friendly npc
		r,g,b = unpack(ElvDB.oUF_colors.power["MANA"])
		frame.isFriendly = true
	elseif r+g > 1.95 then -- neutral
		r,g,b = unpack(ElvDB.oUF_colors.reaction[4])
		frame.isFriendly = false
	elseif r+g == 0 then -- friendly player
		r,g,b = unpack(ElvDB.oUF_colors.reaction[5])
		frame.isFriendly = true
	else -- enemy player
		frame.isFriendly = false
	end
	frame.hp:SetStatusBarColor(r,g,b)
end

local function UpdateObjects(frame)
	local frame = frame:GetParent()
	
	local r, g, b = frame.hp:GetStatusBarColor()
	local r, g, b = floor(r*100+.5)/100, floor(g*100+.5)/100, floor(b*100+.5)/100
	local classname = ""
	
	
	frame.hp:ClearAllPoints()
	frame.hp:SetSize(hpWidth, hpHeight)	
	frame.hp:SetPoint('TOP', frame, 'TOP', 0, -noscalemult*3)
	frame.hp:GetStatusBarTexture():SetHorizTile(true)
			
	--Class Icons
	for class, color in pairs(RAID_CLASS_COLORS) do
		if RAID_CLASS_COLORS[class].r == r and RAID_CLASS_COLORS[class].g == g and RAID_CLASS_COLORS[class].b == b then
			classname = class
		end
	end
	if (classname) then
		texcoord = CLASS_BUTTONS[classname]
		if texcoord then
			frame.hasclass = true
		else
			texcoord = {0.5, 0.75, 0.5, 0.75}
			frame.hasclass = false
		end
	else
		texcoord = {0.5, 0.75, 0.5, 0.75}
		frame.hasclass = false
	end
	
	if frame.hp.rcolor == 0 and frame.hp.gcolor == 0 and frame.hp.bcolor ~= 0 then
		texcoord = {0.5, 0.75, 0.5, 0.75}
		frame.hasclass = true
	end
	frame.class:SetTexCoord(texcoord[1],texcoord[2],texcoord[3],texcoord[4])
	
	--create variable for original colors
	Colorize(frame)
	frame.hp.rcolor, frame.hp.gcolor, frame.hp.bcolor = frame.hp:GetStatusBarColor()
	frame.hp.hpbg:SetTexture(frame.hp.rcolor, frame.hp.gcolor, frame.hp.bcolor, 0.25)
	
	--Set the name text
	frame.name:SetText(frame.oldname:GetText())
	
	--Setup level text
	local level, elite, mylevel = tonumber(frame.oldlevel:GetText()), frame.elite:IsShown(), UnitLevel("player")
	frame.hp.level:ClearAllPoints()
	if ElvCF["nameplate"].showhealth == true then
		frame.hp.level:SetPoint("RIGHT", frame.hp, "RIGHT", 2, 0)
	else
		frame.hp.level:SetPoint("RIGHT", frame.hp, "LEFT", -1, 0)
	end
	
	frame.hp.level:SetTextColor(frame.oldlevel:GetTextColor())
	if frame.boss:IsShown() then
		frame.hp.level:SetText("B")
		frame.hp.level:SetTextColor(0.8, 0.05, 0)
		frame.hp.level:Show()
	elseif not elite and level == mylevel then
		frame.hp.level:Hide()
	else
		frame.hp.level:SetText(level..(elite and "+" or ""))
		frame.hp.level:Show()
	end
	
	frame.overlay:ClearAllPoints()
	frame.overlay:SetAllPoints(frame.hp)

	HideObjects(frame)
end

local function UpdateCastbar(frame)
	frame:ClearAllPoints()
	frame:SetSize(cbWidth, cbHeight)
	frame:SetPoint('TOP', frame:GetParent().hp, 'BOTTOM', 0, -8)
	frame:GetStatusBarTexture():SetHorizTile(true)

	if(not frame.shield:IsShown()) then
		frame:SetStatusBarColor(0.78, 0.25, 0.25, 1)
	end
	
	local frame = frame:GetParent()
	frame.castbarbackdrop_tex:ClearAllPoints()
	frame.castbarbackdrop_tex:SetPoint("TOPLEFT", frame.cb, "TOPLEFT", -noscalemult*3, noscalemult*3)
	frame.castbarbackdrop_tex:SetPoint("BOTTOMRIGHT", frame.cb, "BOTTOMRIGHT", noscalemult*3, -noscalemult*3)
end	

local function UpdateCastText(frame, curValue)
	local minValue, maxValue = frame:GetMinMaxValues()
	
	if UnitChannelInfo("target") then
		frame.time:SetFormattedText("%.1f ", curValue)
		frame.name:SetText(select(1, (UnitChannelInfo("target"))))
	end
	
	if UnitCastingInfo("target") then
		frame.time:SetFormattedText("%.1f ", maxValue - curValue)
		frame.name:SetText(select(1, (UnitCastingInfo("target"))))
	end
end

local OnValueChanged = function(self, curValue)
	UpdateCastText(self, curValue)
	if self.needFix then
		UpdateCastbar(self)
		self.needFix = nil
	end
end

local OnSizeChanged = function(self)
	self.needFix = true
end

local function OnHide(frame)
	frame.hp:SetStatusBarColor(frame.hp.rcolor, frame.hp.gcolor, frame.hp.bcolor)
	frame.overlay:Hide()
	frame.cb:Hide()
	--frame.unit = nil
	--frame.guid = nil
	frame.hasclass = nil
	frame.isFriendly = nil
	frame.hp.rcolor = nil
	frame.hp.gcolor = nil
	frame.hp.bcolor = nil
	if frame.icons then
		for _,icon in ipairs(frame.icons) do
			icon:Hide()
		end
	end	
	frame:SetScript("OnUpdate",nil)
end

--[[local function CreateAuraIcon(parent)
	local button = CreateFrame("Frame",nil,parent)
	ElvDB.SetTemplate(button)
	button:SetHeight(FONTSIZE)
	button:SetWidth(button:GetHeight())
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT",button,"TOPLEFT", noscalemult*3,-noscalemult*3)
	button.icon:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-noscalemult*3,noscalemult*3)
	button.cd = CreateFrame("Cooldown",nil,button)
	button.cd:SetAllPoints(button)
	button.cd:SetReverse(true)
	button.count = button:CreateFontString(nil,"OVERLAY")
	button.count:SetFont(FONT,FONTSIZE,FONTFLAG)
	button.count:SetPoint("TOPLEFT")
	return button
end

local function UpdateAuraIcon(button, unit, index, filter)
	local _, _, icon, count, debuffType, duration, expirationTime,_,_,spellID = UnitAura(unit,index,filter)
	button.icon:SetTexture(icon)
	button.cd:SetCooldown(expirationTime-duration,duration)
	button.expirationTime = expirationTime
	button.duration = duration
	button.spellID = spellID
	button.count:SetText(count)
end

local function buffsSort(a,b)
	if a:IsShown() ~= b:IsShown() then return a:IsShown() end
	if a.expirationTime == 0 then return false end
	return a.expirationTime < b.expirationTime
end

local tsort = table.sort
local function SortAuraIcons(icons)
	tsort(icons,buffsSort)
end

-- Anchor Opposites
local oppAnchor = {
	TOP = "BOTTOM",
	BOTTOM = "TOP",
	RIGHT = "LEFT",
	LEFT = "RIGHT",
}

local match, ceil, floor, min, max = string.match, math.ceil, math.floor, math.min, math.max
local filterTable, tinsert, twipe, tsort = {},table.insert,table.wipe, table.sort
local function ArrangeGrid(frames, direction, wrapPoint, spacing, skipHidden, sortFunc)
	assert(frames and type(frames)=="table")
	-- Filter the frames if necessary
	twipe(filterTable)
	for _,frame in ipairs(frames) do
		if not skipHidden or frame:IsShown() then tinsert(filterTable,frame) end
	end
	
	frames = filterTable
	if sortFunc then tsort(frames,sortFunc) end
	if #frames == 0 then return "TOPLEFT",0,0 end
	direction, wrapPoint, spacing = direction or "RIGHT", wrapPoint or -1, spacing or 0
	-- Parse the direction string
	local dir1 = direction
	local dir2 = direction
	if direction ~= "STACK" then
		dir1 = match(direction,"^(RIGHT)") or match(direction,"^(LEFT)") or match(direction,"^(UP)") or match(direction,"^(DOWN)")
		dir2 = match(direction,"^"..dir1.."(..*)$")
	end
	-- Translate to anchoring points
	local sx1, sy1, sx2, sy2 = 0, 0, 0, 0
	dir1 = (dir1 == "UP" and "TOP") or (dir1 == "DOWN" and "BOTTOM") or (dir1 == "STACK" and "CENTER") or dir1
	dir2 = (dir2 == "UP" and "TOP") or (dir2 == "DOWN" and "BOTTOM") or (dir2 == "STACK" and "CENTER") or dir2
	sy1 = (dir1 == "TOP" and spcaing) or (dir1 == "BOTTOM" and -spacing) or 0
	sy2 = (dir2 == "TOP" and spacing) or (dir2 == "BOTTOM" and -spacing) or 0
	sx1 = (dir1 == "RIGHT" and spacing) or (dir1 == "LEFT" and -spacing) or 0
	sx2 = (dir2 == "RIGHT" and spacing) or (dir2 == "LEFT" and -spacing) or 0	
	-- Anchor all the frames
	local count,frmLvl = #frames, frames[1]:GetFrameLevel()
	if not dir2 or wrapPoint == -1 then wrapPoint = count end -- Only wrap if we know which way
	for i=1,ceil(count/wrapPoint) do
		for j=1,min(wrapPoint,count-(i-1)*wrapPoint) do
			local frame = frames[(i-1)*wrapPoint+j]
			frame:SetFrameLevel(frmLvl)
			frmLvl = frmLvl + 1
			frame:ClearAllPoints()
			if j == 1 and i > 1 then
				frame:SetPoint(oppAnchor[dir2],frames[(i-2)*wrapPoint+1], dir2, sx2, sy2)
			elseif j > 1 then
				frame:SetPoint(oppAnchor[dir1],frames[(i-1)*wrapPoint+j-1],dir1, sx1, sy1)
			end
		end
	end
	-- Calculate the size & anchor point
	local rows,cols = ceil(count/wrapPoint),max(min(count,wrapPoint),1)
	if dir1 == "TOP" or dir1 == "BOTTOM" then cols, rows = rows, cols end
	local width, height = frames[1]:GetWidth() + spacing, frames[1]:GetHeight() + spacing
	width, height = cols*width-spacing, rows*height-spacing
	local first, second
	if dir1 == "TOP" or dir1 == "BOTTOM" then first = oppAnchor[dir1] else second = oppAnchor[dir1] end
	if dir2 == "TOP" or dir2 == "BOTTOM" then first = oppAnchor[dir2] else second = (second or "")..(oppAnchor[dir2] or "") end
	return (first or "TOP")..(second or ""), width, height,frames[1]
end

local tab = CLASS_FILTERS[ElvDB.myclass].target
local function OnAura(frame, unit, ...)
	if unit ~= frame.unit or not frame.icons then return end
	if not tab then return end
	local i = 1
	for k = 1,40 do
		local match
		local _,_,_,_,_,_,duration,_,caster,_,_,spellid = select(6,UnitAura(unit,k,"HELPFUL"))
		if duration and caster == "player" then
			if not frame.icons[i] then frame.icons[i] = CreateAuraIcon(frame) end
			local icon = frame.icons[i]
			if i == 1 then icon:SetPoint("RIGHT",frame.icons,"RIGHT") end
			i = i + 1
			UpdateAuraIcon(icon, unit, k, "HELPFUL")
		end
		duration,_,caster,_,_,spellid = select(6,UnitAura(unit,k,"HARMFUL"))
		for i, tab in pairs(tab) do
			local id = tab.id
			if spellid == id then match = true end
		end
		if duration and caster == "player" and match == true then
			if not frame.icons[i] then frame.icons[i] = CreateAuraIcon(frame) end
			local icon = frame.icons[i]
			if i == 1 then icon:SetPoint("RIGHT",frame.icons,"RIGHT") end
			i = i + 1
			UpdateAuraIcon(icon, unit, k, "HARMFUL")
		end
	end
	for k = i, #frame.icons do frame.icons[k]:Hide() end
	frame.icons.n = i-1
	SortAuraIcons(frame.icons)
	local _, width, _ = ArrangeGrid(frame.icons,"LEFT",nil,ElvDB.Scale(2))
	frame.icons:SetWidth(width)	
end

local function OnCLogEvent(frame, timestamp, event, _,sourceName,_,destGUID,_,_,spellID)
	if frame.guid == destGUID and UnitName("player") == sourceName and event == "SPELL_AURA_REMOVED" then
		for _,icon in ipairs(frame.icons) do if icon.spellID == spellID then icon:Hide() end end
		SortAuraIcons(frame.icons)
		local _, width, _ = ArrangeGrid(frame.icons,"LEFT",nil,ElvDB.Scale(2))
		frame.icons:SetWidth(width)				
	end
end

local function OnEvent(frame, event, ...)
	-- UnitID detection
	if event == "PLAYER_TARGET_CHANGED" and frame:GetAlpha() == 1 then
		frame.guid = UnitGUID("target")
		frame.unit = "target"
		OnAura(frame, frame.unit)
		return
	elseif event == "UPDATE_MOUSEOVER_UNIT" and frame.overlay:IsShown() then
		frame.guid = UnitGUID("mouseover")
		frame.unit = "mouseover"
		OnAura(frame, frame.unit)
		return
	elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
		frame.unit = nil
	else
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then 
			OnCLogEvent(frame, ...)
		else
			if UnitName("target") == frame.name:GetText() and frame:GetAlpha() == 1 then
				frame.unit = "target"
				frame.guid = UnitGUID("target")
				OnAura(frame, ...)
			end
		end
	end
end]]

local function SkinObjects(frame)
	local hp, cb = frame:GetChildren()
	local threat, hpborder, cbshield, cbborder, cbicon, overlay, oldname, oldlevel, bossicon, raidicon, elite = frame:GetRegions()
	frame.healthOriginal = hp
	
	--Just make sure these are correct
	hp:SetFrameLevel(9)
	cb:SetFrameLevel(9)
	
	-- Create Cast Icon Backdrop frame
	local healthbarbackdrop_tex = hp:CreateTexture(nil, "BACKGROUND")
	healthbarbackdrop_tex:SetPoint("CENTER")
	healthbarbackdrop_tex:SetWidth(hpWidth + noscalemult*6)
	healthbarbackdrop_tex:SetHeight(hpHeight + noscalemult*6)
	healthbarbackdrop_tex:SetTexture(0.1, 0.1, 0.1)
	frame.healthbarbackdrop_tex = healthbarbackdrop_tex
	
	--Create our fake border.. fuck blizz
	local healthbarborder_tex1 = hp:CreateTexture(nil, "BORDER")
	healthbarborder_tex1:SetPoint("TOPLEFT", hp, "TOPLEFT", -noscalemult*2, noscalemult*2)
	healthbarborder_tex1:SetPoint("TOPRIGHT", hp, "TOPRIGHT", noscalemult*2, noscalemult*2)
	healthbarborder_tex1:SetHeight(noscalemult)
	healthbarborder_tex1:SetTexture(0.3, 0.3, 0.3)	
	frame.healthborder_tex1 = healthbarborder_tex1
	
	local healthbarborder_tex2 = hp:CreateTexture(nil, "BORDER")
	healthbarborder_tex2:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", -noscalemult*2, -noscalemult*2)
	healthbarborder_tex2:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", noscalemult*2, -noscalemult*2)
	healthbarborder_tex2:SetHeight(noscalemult)
	healthbarborder_tex2:SetTexture(0.3, 0.3, 0.3)	
	frame.healthborder_tex2 = healthbarborder_tex2
	
	local healthbarborder_tex3 = hp:CreateTexture(nil, "BORDER")
	healthbarborder_tex3:SetPoint("TOPLEFT", hp, "TOPLEFT", -noscalemult*2, noscalemult*2)
	healthbarborder_tex3:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", noscalemult*2, -noscalemult*2)
	healthbarborder_tex3:SetWidth(noscalemult)
	healthbarborder_tex3:SetTexture(0.3, 0.3, 0.3)	
	frame.healthborder_tex3 = healthbarborder_tex3
	
	local healthbarborder_tex4 = hp:CreateTexture(nil, "BORDER")
	healthbarborder_tex4:SetPoint("TOPRIGHT", hp, "TOPRIGHT", noscalemult*2, noscalemult*2)
	healthbarborder_tex4:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", -noscalemult*2, -noscalemult*2)
	healthbarborder_tex4:SetWidth(noscalemult)
	healthbarborder_tex4:SetTexture(0.3, 0.3, 0.3)	
	frame.healthborder_tex4 = healthbarborder_tex4
	
	hp:SetStatusBarTexture(TEXTURE)
	frame.hp = hp
	
	--Actual Background for the Healthbar
	hp.hpbg = hp:CreateTexture(nil, 'BORDER')
	hp.hpbg:SetAllPoints(hp)
	hp.hpbg:SetTexture(1,1,1,0.25)  
	
	--Create Overlay Highlight
	frame.overlay = overlay
	frame.overlay:SetTexture(1,1,1,0.15)
	frame.overlay:SetAllPoints(hp)
	
	--Create Name
	hp.level = hp:CreateFontString(nil, "OVERLAY")
	hp.level:SetFont(FONT, FONTSIZE, FONTFLAG)
	hp.level:SetTextColor(1, 1, 1)
	hp.level:SetShadowOffset(ElvDB.mult, -ElvDB.mult)	
	
	--Needed for level text
	frame.oldlevel = oldlevel
	frame.boss = bossicon
	frame.elite = elite
	
	--Create Health Text
	if ElvCF["nameplate"].showhealth == true then
		hp.value = hp:CreateFontString(nil, "OVERLAY")	
		hp.value:SetFont(FONT, FONTSIZE, FONTFLAG)
		hp.value:SetPoint("CENTER", hp)
		hp.value:SetTextColor(1,1,1)
		hp.value:SetShadowOffset(ElvDB.mult, -ElvDB.mult)
	end
	
	-- Create Cast Bar Backdrop frame
	local castbarbackdrop_tex = cb:CreateTexture(nil, "BACKGROUND")
	castbarbackdrop_tex:SetPoint("TOPLEFT", cb, "TOPLEFT", -noscalemult*3, noscalemult*3)
	castbarbackdrop_tex:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", noscalemult*3, -noscalemult*3)
	castbarbackdrop_tex:SetTexture(0.1, 0.1, 0.1)
	frame.castbarbackdrop_tex = castbarbackdrop_tex
	
	--Create our fake border.. fuck blizz
	local castbarborder_tex1 = cb:CreateTexture(nil, "BORDER")
	castbarborder_tex1:SetPoint("TOPLEFT", cb, "TOPLEFT", -noscalemult*2, noscalemult*2)
	castbarborder_tex1:SetPoint("TOPRIGHT", cb, "TOPRIGHT", noscalemult*2, noscalemult*2)
	castbarborder_tex1:SetHeight(noscalemult)
	castbarborder_tex1:SetTexture(0.3, 0.3, 0.3)	
	
	local castbarborder_tex2 = cb:CreateTexture(nil, "BORDER")
	castbarborder_tex2:SetPoint("BOTTOMLEFT", cb, "BOTTOMLEFT", -noscalemult*2, -noscalemult*2)
	castbarborder_tex2:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", noscalemult*2, -noscalemult*2)
	castbarborder_tex2:SetHeight(noscalemult)
	castbarborder_tex2:SetTexture(0.3, 0.3, 0.3)	
	
	local castbarborder_tex3 = cb:CreateTexture(nil, "BORDER")
	castbarborder_tex3:SetPoint("TOPLEFT", cb, "TOPLEFT", -noscalemult*2, noscalemult*2)
	castbarborder_tex3:SetPoint("BOTTOMLEFT", cb, "BOTTOMLEFT", noscalemult*2, -noscalemult*2)
	castbarborder_tex3:SetWidth(noscalemult)
	castbarborder_tex3:SetTexture(0.3, 0.3, 0.3)	
	
	local castbarborder_tex4 = cb:CreateTexture(nil, "BORDER")
	castbarborder_tex4:SetPoint("TOPRIGHT", cb, "TOPRIGHT", noscalemult*2, noscalemult*2)
	castbarborder_tex4:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", -noscalemult*2, -noscalemult*2)
	castbarborder_tex4:SetWidth(noscalemult)
	castbarborder_tex4:SetTexture(0.3, 0.3, 0.3)	
	
	--Setup CastBar Icon
	cbicon:ClearAllPoints()
	cbicon:SetPoint("TOPLEFT", hp, "TOPRIGHT", 8, 0)		
	cbicon:SetSize(iconSize, iconSize)
	cbicon:SetTexCoord(.07, .93, .07, .93)
	cbicon:SetDrawLayer("OVERLAY")

	-- Create Cast Icon Backdrop frame
	local casticonbackdrop_tex = cb:CreateTexture(nil, "BACKGROUND")
	casticonbackdrop_tex:SetPoint("TOPLEFT", cbicon, "TOPLEFT", -noscalemult*3, noscalemult*3)
	casticonbackdrop_tex:SetPoint("BOTTOMRIGHT", cbicon, "BOTTOMRIGHT", noscalemult*3, -noscalemult*3)
	casticonbackdrop_tex:SetTexture(0.1, 0.1, 0.1)
	
	local casticonborder_tex = cb:CreateTexture(nil, "BORDER")
	casticonborder_tex:SetPoint("TOPLEFT", cbicon, "TOPLEFT", -noscalemult*2, noscalemult*2)
	casticonborder_tex:SetPoint("BOTTOMRIGHT", cbicon, "BOTTOMRIGHT", noscalemult*2, -noscalemult*2)
	casticonborder_tex:SetTexture(0.3, 0.3, 0.3)	
	
	--Create Health Backdrop Frame
	local casticonbackdrop2_tex = cb:CreateTexture(nil, "ARTWORK")
	casticonbackdrop2_tex:SetPoint("TOPLEFT", cbicon, "TOPLEFT", -noscalemult, noscalemult)
	casticonbackdrop2_tex:SetPoint("BOTTOMRIGHT", cbicon, "BOTTOMRIGHT", noscalemult, -noscalemult)
	casticonbackdrop2_tex:SetTexture(0.1, 0.1, 0.1)
	
	--Create Cast Time Text
	cb.time = cb:CreateFontString(nil, "ARTWORK")
	cb.time:SetPoint("RIGHT", cb, "LEFT", -1, 0)
	cb.time:SetFont(FONT, FONTSIZE, FONTFLAG)
	cb.time:SetTextColor(1, 1, 1)
	cb.time:SetShadowOffset(ElvDB.mult, -ElvDB.mult)

	--Create Cast Name Text
	cb.name = cb:CreateFontString(nil, "ARTWORK")
	cb.name:SetPoint("TOP", cb, "BOTTOM", 0, -3)
	cb.name:SetFont(FONT, FONTSIZE, FONTFLAG)
	cb.name:SetTextColor(1, 1, 1)
	cb.name:SetShadowOffset(ElvDB.mult, -ElvDB.mult)
	
	cb.icon = cbicon
	cb.shield = cbshield
	cb:HookScript('OnShow', UpdateCastbar)
	cb:HookScript('OnSizeChanged', OnSizeChanged)
	cb:HookScript('OnValueChanged', OnValueChanged)	
	cb:SetStatusBarTexture(TEXTURE)
	frame.cb = cb

	--Create Name Text
	local name = hp:CreateFontString(nil, 'OVERLAY')
	name:SetPoint('BOTTOMLEFT', hp, 'TOPLEFT', -10, 3)
	name:SetPoint('BOTTOMRIGHT', hp, 'TOPRIGHT', 10, 3)
	name:SetFont(FONT, FONTSIZE, FONTFLAG)
	name:SetShadowOffset(ElvDB.mult, -ElvDB.mult)
	frame.oldname = oldname
	frame.name = name
		
	--Reposition and Resize RaidIcon
	raidicon:ClearAllPoints()
	raidicon:SetPoint("BOTTOM", hp, "TOP", 0, 16)
	raidicon:SetSize(iconSize*1.4, iconSize*1.4)
	raidicon:SetTexture(ElvCF["media"].raidicons)	
	frame.raidicon = raidicon
	
	--Create Class Icon
	local cIconTex = hp:CreateTexture(nil, "OVERLAY")
	cIconTex:SetPoint("BOTTOM", hp, "TOP", 0, 16)
	cIconTex:SetTexture("Interface\\WorldStateFrame\\Icons-Classes")
	cIconTex:SetSize(iconSize, iconSize)
	frame.class = cIconTex
	
	-- Aura tracking
	--[[if ElvCF["nameplate"].trackauras == true then
		frame.icons = CreateFrame("Frame",nil,frame.hp)
		frame.icons:SetPoint("BOTTOMLEFT",frame.hp,"TOPLEFT", -10, FONTSIZE+5)
		frame.icons:SetWidth(20 + hpWidth)
		frame.icons:SetFrameLevel(frame.hp:GetFrameLevel()+2)
		frame:RegisterEvent("UNIT_AURA")
		frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
		frame:RegisterEvent("PLAYER_TARGET_CHANGED")	
		frame:HookScript("OnEvent",OnEvent)		
	end]]
	
	--Hide Old Stuff
	QueueObject(frame, oldlevel)
	QueueObject(frame, threat)
	QueueObject(frame, hpborder)
	QueueObject(frame, cbshield)
	QueueObject(frame, cbborder)
	QueueObject(frame, oldname)
	QueueObject(frame, bossicon)
	QueueObject(frame, elite)
	
	UpdateObjects(hp)
	UpdateCastbar(cb)
	
	frame.hp:HookScript('OnShow', UpdateObjects)
	frame:HookScript('OnHide', OnHide)
	frames[frame] = true
end

local select = select
local function HookFrames(...)
	for index = 1, select('#', ...) do
		local frame = select(index, ...)
		local region = frame:GetRegions()

		if(not frames[frame] and not frame:GetName() and region and region:GetObjectType() == 'Texture' and region:GetTexture() == OVERLAY) then
			SkinObjects(frame)
			frame.region = region
		end
	end
end


CreateFrame('Frame'):SetScript('OnUpdate', function(self, elapsed)
	if(WorldFrame:GetNumChildren() ~= numChildren) then
		numChildren = WorldFrame:GetNumChildren()
		HookFrames(WorldFrame:GetChildren())
	end

	if(self.elapsed and self.elapsed > 0.2) then
		for frame in pairs(frames) do
			UpdateThreat(frame, self.elapsed)
		end
		
		self.elapsed = 0
	else
		self.elapsed = (self.elapsed or 0) + elapsed
	end
	
	ForEachPlate(CheckBlacklist)
	ForEachPlate(HideDrunkenText)
end)

if ElvCF["nameplate"].combat == true then
	NamePlates:RegisterEvent("PLAYER_REGEN_ENABLED")
	NamePlates:RegisterEvent("PLAYER_REGEN_DISABLED")
	NamePlates:RegisterEvent("PLAYER_ENTERING_WORLD")
	function NamePlates:PLAYER_REGEN_ENABLED()
		SetCVar("nameplateShowEnemies", 0)
	end
	
	function NamePlates:PLAYER_REGEN_DISABLED()
		SetCVar("nameplateShowEnemies", 1)
	end
	
	function NamePlates:PLAYER_ENTERING_WORLD()
		if InCombatLockdown() then
			SetCVar("nameplateShowEnemies", 1)
		else
			SetCVar("nameplateShowEnemies", 0)
		end
	end
end