-- Courier: data collection (alts, friends, Battle.net friends, guild, recent recipients)
local ADDON, ns = ...

local MAX_RECENT = 20

ns.player = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local classLookup
-- Friend/BNet APIs give a localized class name; map it back to the class file
-- (e.g. "Mage" -> "MAGE") so we can colour it.
function ns.ClassFileFromLocalized(localized)
	if not localized then return nil end
	if not classLookup then
		classLookup = {}
		for file, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do classLookup[name] = file end
		for file, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do classLookup[name] = file end
	end
	return classLookup[localized]
end

function ns.Colorize(text, classFile)
	local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if color then return color:WrapTextInColorCode(text) end
	return text
end

-- Class icon + class-coloured name. Pass noColor to keep the text's own colour (e.g. grey for offline).
function ns.ClassLabel(text, classFile, noColor)
	local icon = ""
	if classFile and CreateAtlasMarkup then
		icon = CreateAtlasMarkup("classicon-" .. classFile:lower(), 14, 14) .. " "
	end
	return icon .. (noColor and text or ns.Colorize(text, classFile))
end

-- WoW Forever uses region-wide unique names ("Kathriel Stormfist") and groups
-- characters by ruleset (PvP, RPPvP, ...) instead of by realm.
ns.regionalNames = RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() or false

-- Same ruleset key Syndicator uses, so our "Name-Realm" keys match theirs.
local function GetRulesetName()
	local function active(rule) return Enum.GameRule[rule] and C_GameRules.IsGameRuleActive(Enum.GameRule[rule]) end
	if active("PvPRuleset") and active("RPRuleset") then return "RPPvP"
	elseif active("PvPRuleset") then return "PvP"
	elseif active("RPRuleset") then return "RP"
	elseif active("HardcoreRuleset") then return "HC"
	end
	return "PvE"
end

local function StripRealm(realm)
	if not realm or realm == "" then return nil end
	return (realm:gsub("[%s%-']", ""))
end

-- Split "Name-Realm" into name, realm (splits on the last "-"). Realm defaults to the player's.
function ns.SplitName(full)
	local name, realm = full:match("^(.*)%-([^%-]*)$")
	if not name then name = full end
	return name, StripRealm(realm) or ns.player.realm
end

-- With regional names, any realm string we're handed is mapped onto a ruleset key.
local RULESETS = { "RPPvP", "PvP", "RP", "HC", "PvE" }
local function RegionalRealm(realm)
	realm = StripRealm(realm)
	if not realm then return nil end
	for _, key in ipairs(RULESETS) do
		if realm:find(key, 1, true) then return key end
	end
end

-- Battle.net doesn't give a realm on Forever, but the rich presence text does:
-- "Forever - PvP - Riverglades", "Forever - Normal - Orgrimmar". Returns a ruleset key or nil.
function ns.RulesetFromPresence(presence)
	if not presence or presence == "" then return nil end
	local middle = presence:match("^.- %- (.+) %- .-$")
	if not middle then return nil end
	local m = middle:gsub("[%s%-]", ""):lower()
	local rp = m:find("rp", 1, true) or m:find("roleplay", 1, true)
	local pvp = m:find("pvp", 1, true)
	if m:find("hardcore", 1, true) then return "HC"
	elseif rp and pvp then return "RPPvP"
	elseif pvp then return "PvP"
	elseif rp then return "RP"
	elseif m:find("normal", 1, true) or m:find("pve", 1, true) then return "PvE"
	end
end

-- Can we mail someone on this realm? With regional names: only your own ruleset.
-- If the realm can't be read we let it through rather than hide a valid contact.
function ns.IsMailableRealm(realm)
	if not realm or realm == "" then return true end
	if ns.regionalNames then
		local ruleset = RegionalRealm(realm)
		return not ruleset or ruleset == ns.player.realm
	end
	return true
end

function ns.FullName(name, realm)
	if ns.regionalNames then
		return name .. "-" .. (RegionalRealm(realm) or ns.player.realm)
	end
	return name .. "-" .. (StripRealm(realm) or ns.player.realm)
end

-- What to type into the "To:" box. Same-realm characters don't need a suffix,
-- and region-unique names never do.
function ns.RecipientText(full)
	local name, realm = ns.SplitName(full)
	if ns.regionalNames or realm == ns.player.realm then return name end
	return name .. "-" .. realm
end

-- Realms you can mail to (your own plus any connected realms).
-- With regional names that's just your current ruleset.
local function MailableRealms()
	local realms = { [ns.player.realm] = true }
	if not ns.regionalNames and GetAutoCompleteRealms then
		for _, r in ipairs(GetAutoCompleteRealms() or {}) do realms[StripRealm(r)] = true end
	end
	return realms
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------

function ns.InitDB()
	CourierDB = CourierDB or {}
	CourierDB.chars = CourierDB.chars or {}
	CourierDB.recent = CourierDB.recent or {}

	local p = ns.player
	if ns.regionalNames then
		local first, surname = UnitName("player")
		local sep = Constants.CharacterNameSeparatorConsts and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
		p.name = (surname and surname ~= "") and (first .. sep .. surname) or first
		p.realm = GetRulesetName()
	else
		p.name = UnitName("player")
		p.realm = StripRealm(GetNormalizedRealmName()) or StripRealm(GetRealmName()) or "Unknown"
	end
	p.faction = UnitFactionGroup("player")
	p.full = p.name .. "-" .. p.realm

	-- Drop broken entries saved by earlier versions (blank realm, e.g. "Kathriel-")
	for key, c in pairs(CourierDB.chars) do
		if not c.realm or c.realm == "" then CourierDB.chars[key] = nil end
	end

	ns.UpdateCurrentCharacter()
end

function ns.UpdateCurrentCharacter()
	local p = ns.player
	if not p.full then return end
	local _, classFile = UnitClass("player")
	CourierDB.chars[p.full] = {
		name = p.name,
		realm = p.realm,
		faction = p.faction,
		class = classFile,
		level = UnitLevel("player"),
		lastSeen = time(),
	}
end

function ns.ForgetCharacter(full)
	if not full:find("-", 1, true) then full = full .. "-" .. ns.player.realm end
	for key in pairs(CourierDB.chars) do
		if key:lower() == full:lower() then
			CourierDB.chars[key] = nil
			return key
		end
	end
end

function ns.AddRecent(recipient)
	if not recipient or recipient == "" then return end
	local name, realm = ns.SplitName(recipient)
	-- Normalise capitalisation: "kathriel stormfist" -> "Kathriel Stormfist"
	name = name:lower():gsub("^%l", string.upper):gsub(" %l", string.upper)
	local full = ns.FullName(name, realm)
	if full == ns.player.full then return end

	local recent = CourierDB.recent
	for i = #recent, 1, -1 do
		if recent[i]:lower() == full:lower() then table.remove(recent, i) end
	end
	table.insert(recent, 1, full)
	while #recent > MAX_RECENT do table.remove(recent) end
end

---------------------------------------------------------------------------
-- Contact lists. Each entry: { full = "Name-Realm", label = "...", online = bool }
---------------------------------------------------------------------------

local function byOnlineThenName(a, b)
	if a.online ~= b.online then return a.online end
	return a.sortKey < b.sortKey
end

-- Characters known to Syndicator (if installed), in Courier's own format.
-- Syndicator doesn't store level, so we fill that in from Courier's data when we have it.
local function GetSyndicatorChars()
	local chars = {}
	if not (Syndicator and Syndicator.API and Syndicator.API.GetAllCharacters) then return chars end
	local ok, names = pcall(Syndicator.API.GetAllCharacters)
	if not ok or type(names) ~= "table" then return chars end
	for _, full in ipairs(names) do
		local data = Syndicator.API.GetByCharacterFullName(full)
		local d = data and data.details
		if d and d.character and d.realmNormalized then
			chars[full] = {
				name = d.character,
				realm = d.realmNormalized,
				faction = d.faction,
				class = d.className,
			}
		end
	end
	return chars
end

-- Courier's own records merged with Syndicator's (Courier wins where both exist).
function ns.GetAllKnownChars()
	local merged = GetSyndicatorChars()
	for full, c in pairs(CourierDB.chars) do merged[full] = c end
	return merged
end

function ns.GetAlts()
	local list, realms = {}, MailableRealms()
	for full, c in pairs(ns.GetAllKnownChars()) do
		if full ~= ns.player.full and c.faction == ns.player.faction and realms[c.realm] then
			local label = ns.ClassLabel(c.name, c.class)
			if c.realm ~= ns.player.realm then label = label .. " |cff999999- " .. c.realm .. "|r" end
			list[#list + 1] = { full = full, label = label, classFile = c.class, sortKey = full:lower() }
		end
	end
	table.sort(list, function(a, b) return a.sortKey < b.sortKey end)
	return list
end

function ns.GetFriends()
	local list = {}
	if not C_FriendList then return list end
	for i = 1, C_FriendList.GetNumFriends() or 0 do
		local info = C_FriendList.GetFriendInfoByIndex(i)
		if info and info.name and info.name ~= "" then
			local full = ns.FullName(ns.SplitName(info.name))
			local short = ns.RecipientText(full)
			local classFile = ns.ClassFileFromLocalized(info.className)
			local label = info.connected and ns.ClassLabel(short, classFile)
				or ns.ClassLabel("|cff808080" .. short .. "|r", classFile, true)
			list[#list + 1] = {
				full = full,
				label = label,
				classFile = classFile,
				online = info.connected and true or false,
				sortKey = short:lower(),
			}
		end
	end
	table.sort(list, byOnlineThenName)
	return list
end

-- Battle.net friends: characters currently online in this game (WoW Forever) on your faction.
function ns.GetBNetFriends()
	local list = {}
	if not (BNGetNumFriends and C_BattleNet) then return list end
	local seen = {}
	for i = 1, BNGetNumFriends() or 0 do
		local account = C_BattleNet.GetFriendAccountInfo(i)
		local numGame = C_BattleNet.GetFriendNumGameAccounts(i) or 0
		for j = 1, numGame do
			local ga = C_BattleNet.GetFriendGameAccountInfo(i, j)
			if ga and ga.clientProgram == BNET_CLIENT_WOW and ga.characterName and ga.characterName ~= ""
				and (not ga.wowProjectID or ga.wowProjectID == WOW_PROJECT_ID)
				and (not ga.factionName or ga.factionName == ns.player.faction)
				and ns.IsMailableRealm(ga.realmName or ns.RulesetFromPresence(ga.richPresence)) then
				local full = ns.FullName(ga.characterName, ga.realmName or ns.RulesetFromPresence(ga.richPresence))
				if not seen[full] then
					seen[full] = true
					local classFile = ga.classFileName or ga.classFilename or ns.ClassFileFromLocalized(ga.className)
					local label = ns.ClassLabel(ns.RecipientText(full), classFile)
					if account and account.accountName then
						label = label .. " |cff82c5ff(" .. account.accountName .. ")|r"
					end
					list[#list + 1] = { full = full, label = label, classFile = classFile, online = true, sortKey = full:lower() }
				end
			end
		end
	end
	table.sort(list, byOnlineThenName)
	return list
end

function ns.GetGuild()
	local list = {}
	if not IsInGuild() then return list end
	for i = 1, GetNumGuildMembers() or 0 do
		local name, _, _, _, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
		if name then
			local full = ns.FullName(ns.SplitName(name))
			if full ~= ns.player.full then
				local short = ns.RecipientText(full)
				local label = online and ns.ClassLabel(short, classFile)
					or ns.ClassLabel("|cff808080" .. short .. "|r", classFile, true)
				list[#list + 1] = { full = full, label = label, classFile = classFile, online = online and true or false, sortKey = full:lower() }
			end
		end
	end
	table.sort(list, byOnlineThenName)
	return list
end

-- Recent recipients, tagged with what they are to you: "Alt", "Friend", "Battle.net", "Guild".
function ns.GetRecent()
	local tags, classes = {}, {}
	local function collect(entries, tag)
		for _, e in ipairs(entries) do
			local key = e.full:lower()
			tags[key] = tags[key] or {}
			table.insert(tags[key], tag)
			classes[key] = classes[key] or e.classFile
		end
	end
	collect(ns.GetAlts(), "Alt")
	collect(ns.GetFriends(), "Friend")
	collect(ns.GetBNetFriends(), "Battle.net")
	collect(ns.GetGuild(), "Guild")

	local list, known = {}, ns.GetAllKnownChars()
	for _, full in ipairs(CourierDB.recent) do
		local key = full:lower()
		local c = known[full]
		local label = ns.ClassLabel(ns.RecipientText(full), classes[key] or (c and c.class))
		if tags[key] then
			label = label .. " |cff999999(" .. table.concat(tags[key], ", ") .. ")|r"
		end
		list[#list + 1] = { full = full, label = label }
	end
	return list
end
