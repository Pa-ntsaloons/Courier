-- Courier: total gold waiting in the inbox, with a breakdown on hover
local ADDON, ns = ...

local MAX_SENDERS = 10

---------------------------------------------------------------------------
-- Classifying mail
---------------------------------------------------------------------------

-- Turn a global format string like "Auction successful: %s" into a Lua pattern.
local function SubjectPattern(fmt)
	if type(fmt) ~= "string" or fmt == "" then return nil end
	fmt = fmt:gsub("%%%d?%$?s", "\001")          -- placeholders (%s, %1$s) -> marker
	fmt = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") -- escape magic characters
	return "^" .. fmt:gsub("\001", ".+") .. "$"
end

local salePattern, refundPatterns
local function BuildPatterns()
	if salePattern ~= nil then return end
	salePattern = SubjectPattern(AUCTION_SOLD_MAIL_SUBJECT) or false
	refundPatterns = {}
	for _, fmt in ipairs({ AUCTION_OUTBID_MAIL_SUBJECT, AUCTION_REMOVED_MAIL_SUBJECT, AUCTION_EXPIRED_MAIL_SUBJECT }) do
		local p = SubjectPattern(fmt)
		if p then refundPatterns[#refundPatterns + 1] = p end
	end
end

-- Returns "sale", "refund", "player" or "other".
local function Classify(index, sender, subject, canReply)
	BuildPatterns()
	local invoiceType = GetInboxInvoiceInfo and GetInboxInvoiceInfo(index)
	if invoiceType == "seller" or invoiceType == "seller_temp_invoice" then return "sale" end
	subject = subject or ""
	if salePattern and subject:match(salePattern) then return "sale" end
	for _, p in ipairs(refundPatterns) do
		if subject:match(p) then return "refund" end
	end
	if canReply and sender and sender ~= "" then return "player" end
	return "other"
end

---------------------------------------------------------------------------
-- Scanning the inbox
---------------------------------------------------------------------------

local function Scan()
	local s = {
		total = 0, mails = 0,
		sale = 0, saleCount = 0,
		refund = 0, refundCount = 0,
		player = 0, playerCount = 0,
		other = 0, otherCount = 0,
		cod = 0, codCount = 0,
		senders = {},
	}
	local shown, total = GetInboxNumItems()
	s.notLoaded = math.max((total or 0) - (shown or 0), 0)

	local bySender = {}
	for i = 1, shown or 0 do
		local _, _, sender, subject, money, cod, _, _, _, _, _, canReply = GetInboxHeaderInfo(i)
		if cod and cod > 0 then
			s.cod = s.cod + cod
			s.codCount = s.codCount + 1
		end
		if money and money > 0 then
			local kind = Classify(i, sender, subject, canReply)
			s.total = s.total + money
			s.mails = s.mails + 1
			s[kind] = s[kind] + money
			s[kind .. "Count"] = s[kind .. "Count"] + 1
			if kind == "player" then
				local entry = bySender[sender]
				if not entry then
					entry = { name = sender, money = 0, count = 0 }
					bySender[sender] = entry
					s.senders[#s.senders + 1] = entry
				end
				entry.money = entry.money + money
				entry.count = entry.count + 1
			end
		end
	end
	table.sort(s.senders, function(a, b) return a.money > b.money end)
	return s
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------

local function Money(amount)
	return GetMoneyString(amount, true)
end

local function AddRow(label, amount, count, r, g, b)
	if amount <= 0 then return end
	GameTooltip:AddDoubleLine(("%s |cff999999(%d)|r"):format(label, count), Money(amount), r or 1, g or 0.82, b or 0, 1, 1, 1)
end

local function ShowTooltip(self)
	local s = Scan()
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:AddDoubleLine("Gold in Inbox", Money(s.total), 1, 1, 1, 1, 1, 1)

	if s.total > 0 then
		GameTooltip:AddLine(" ")
		AddRow("Auction sales", s.sale, s.saleCount)
		AddRow("Auction refunds", s.refund, s.refundCount)
		AddRow("From players", s.player, s.playerCount)
		for i = 1, math.min(#s.senders, MAX_SENDERS) do
			local e = s.senders[i]
			local name = e.count > 1 and ("%s (%d)"):format(e.name, e.count) or e.name
			GameTooltip:AddDoubleLine("    " .. name, Money(e.money), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
		end
		if #s.senders > MAX_SENDERS then
			GameTooltip:AddLine(("    and %d more"):format(#s.senders - MAX_SENDERS), 0.6, 0.6, 0.6)
		end
		AddRow("Other", s.other, s.otherCount)
	else
		GameTooltip:AddLine("No mail with gold attached.", 0.6, 0.6, 0.6)
	end

	if s.cod > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(("COD to pay |cff999999(%d)|r"):format(s.codCount), Money(s.cod), 1, 0.3, 0.3, 1, 1, 1)
	end
	if s.notLoaded > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(("%d more mail not loaded yet. Take some mail to see the rest."):format(s.notLoaded), 0.6, 0.6, 0.6, true)
	end
	GameTooltip:Show()
end

local function Update()
	local f = ns.inboxMoney
	if not f then return end
	local s = Scan()
	if s.total > 0 then
		f.text:SetText(Money(s.total) .. (s.notLoaded > 0 and "|cff999999+|r" or ""))
	else
		f.text:SetText("|cff808080" .. Money(0) .. "|r")
	end
	f:SetWidth(f.text:GetStringWidth() + 4)
	if GameTooltip:IsOwned(f) then ShowTooltip(f) end
end

local function CreateInboxMoney()
	if ns.inboxMoney or not InboxFrame then return end

	local f = CreateFrame("Frame", "CourierInboxMoney", InboxFrame)
	f:SetSize(100, 16)
	f:SetPoint("TOPRIGHT", MailFrame or InboxFrame, "TOPRIGHT", -12, -32)
	f:EnableMouse(true)

	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("RIGHT")
	f.text:SetJustifyH("RIGHT")

	f:SetScript("OnEnter", ShowTooltip)
	f:SetScript("OnLeave", GameTooltip_Hide)
	f:SetScript("OnShow", Update)

	ns.inboxMoney = f
	Update()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("MAIL_SHOW")
events:RegisterEvent("MAIL_INBOX_UPDATE")
events:SetScript("OnEvent", function(_, event)
	if event == "MAIL_INBOX_UPDATE" then
		Update()
	else
		CreateInboxMoney()
	end
end)
