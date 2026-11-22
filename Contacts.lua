-- Courier: Contacts button on the Send Mail frame
local ADDON, ns = ...

local GUILD_SCROLL_HEIGHT = 400

---------------------------------------------------------------------------
-- Filling the recipient
---------------------------------------------------------------------------

local function SetRecipient(full)
	SendMailNameEditBox:SetText(ns.RecipientText(full))
	SendMailNameEditBox:SetCursorPosition(0)
	if SendMailSubjectEditBox then SendMailSubjectEditBox:SetFocus() end
end

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------

local function AddSection(root, title, entries, scroll)
	local sub = root:CreateButton(("%s |cff999999(%d)|r"):format(title, #entries))
	if #entries == 0 then
		sub:CreateTitle("|cff808080None|r")
		return
	end
	if scroll and sub.SetScrollMode then sub:SetScrollMode(GUILD_SCROLL_HEIGHT) end
	for _, entry in ipairs(entries) do
		sub:CreateButton(entry.label, function() SetRecipient(entry.full) end)
	end
end

local function GenerateMenu(owner, root)
	root:CreateTitle("Courier Contacts")
	AddSection(root, "Alts", ns.GetAlts())
	AddSection(root, "Recent", ns.GetRecent())
	AddSection(root, "Friends", ns.GetFriends())
	AddSection(root, "Battle.net", ns.GetBNetFriends())
	if IsInGuild() then
		AddSection(root, "Guild", ns.GetGuild(), true)
	end
end

local function OpenMenu(button)
	if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster() -- request a fresh roster for next time
	end
	if C_FriendList and C_FriendList.ShowFriends then
		C_FriendList.ShowFriends()
	end
	MenuUtil.CreateContextMenu(button, GenerateMenu)
end

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------

local function CreateContactsButton()
	if ns.button or not SendMailNameEditBox then return end

	local b = CreateFrame("Button", "CourierContactsButton", SendMailFrame)
	b:SetSize(22, 22)
	b:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 2, 0)
	b:SetNormalTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
	b:SetPushedTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
	b:GetPushedTexture():SetVertexColor(0.7, 0.7, 0.7)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

	b:SetScript("OnClick", OpenMenu)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Contacts")
		GameTooltip:AddLine("Choose an alt, friend, guildmate or recent recipient.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)

	ns.button = b
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("MAIL_SEND_SUCCESS")

-- Remember who we mail: note the name when a send starts, save it once the send succeeds.
local pendingRecipient
local function NotePending(recipient)
	if recipient and recipient ~= "" then pendingRecipient = recipient end
end

f:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		ns.InitDB()
		CreateContactsButton()
		if SendMail then hooksecurefunc("SendMail", NotePending) end
		if C_Mail and C_Mail.SendMail then hooksecurefunc(C_Mail, "SendMail", NotePending) end
		if SendMailMailButton then
			SendMailMailButton:HookScript("PreClick", function() NotePending(SendMailNameEditBox:GetText()) end)
		end
	elseif event == "MAIL_SEND_SUCCESS" then
		if pendingRecipient then
			ns.AddRecent(pendingRecipient)
			pendingRecipient = nil
		end
	elseif event == "MAIL_SHOW" then
		CreateContactsButton()
	else -- level up / logout
		C_Timer.After(0, ns.UpdateCurrentCharacter)
		if event == "PLAYER_LOGOUT" then ns.UpdateCurrentCharacter() end
	end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_COURIER1 = "/courier"
SlashCmdList.COURIER = function(msg)
	local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "alts" then
		print("|cff82c5ffCourier|r known characters:")
		for full, c in pairs(ns.GetAllKnownChars()) do
			print(("  %s - %s (%s)"):format(ns.Colorize(full, c.class), c.faction or "?", c.level or "?"))
		end
	elseif cmd == "forget" and arg ~= "" then
		local removed = ns.ForgetCharacter(arg)
		print("|cff82c5ffCourier|r " .. (removed and ("forgot " .. removed) or ("no character named " .. arg)))
	elseif cmd == "clearrecent" then
		wipe(CourierDB.recent)
		print("|cff82c5ffCourier|r recent recipients cleared.")
	elseif cmd == "debug" then
		local p = ns.player
		print(("|cff82c5ffCourier|r player=%s faction=%s regional=%s project=%s"):format(
			tostring(p.full), tostring(p.faction), tostring(ns.regionalNames), tostring(WOW_PROJECT_ID)))
		print(("  my guid=%s realmName=%s normalized=%s"):format(
			tostring(UnitGUID("player")), tostring(GetRealmName()), tostring(GetNormalizedRealmName())))
		print(("  recent: %d saved"):format(#CourierDB.recent))
		local numFriends = C_FriendList and C_FriendList.GetNumFriends() or 0
		print(("  friends: %d"):format(numFriends))
		for i = 1, numFriends do
			local info = C_FriendList.GetFriendInfoByIndex(i)
			if info then
				print(("    [%d] name=%s class=%s online=%s"):format(i, tostring(info.name), tostring(info.className), tostring(info.connected)))
			end
		end
		local numBN = BNGetNumFriends and BNGetNumFriends() or 0
		print(("  battle.net: %d (client constant=%s)"):format(numBN, tostring(BNET_CLIENT_WOW)))
		for i = 1, numBN do
			for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
				local ga = C_BattleNet.GetFriendGameAccountInfo(i, j)
				if ga and ga.clientProgram == BNET_CLIENT_WOW and ga.characterName then
					print(("    [%d.%d] %s:"):format(i, j, tostring(ga.characterName)))
					local keys = {}
					for k, v in pairs(ga) do
						if type(v) ~= "table" and type(v) ~= "function" then keys[#keys + 1] = k end
					end
					table.sort(keys)
					local parts = {}
					for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(ga[k]) end
					print("      " .. table.concat(parts, " | "))
				end
			end
		end
	else
		print("|cff82c5ffCourier|r commands:")
		print("  /courier alts - list known characters")
		print("  /courier forget Name[-Realm] - remove a character")
		print("  /courier clearrecent - clear recent recipients")
		print("  /courier debug - print what the friend APIs return")
	end
end
