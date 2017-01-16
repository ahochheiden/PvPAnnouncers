-- settings
local selectedAnnouncerPack = "HoN_Default"
local killResetTime = 15

-- locals
local killStreak = 0
local multiKill = 0
local killTime = 0
local soundUpdate = 0
local nextSound = nil

-- kill spree sounds filename table
local spreeSounds = {
	[1] = "firstKill",
	[2] = "silence",
	[3] = "spree3",
	[4] = "spree4",
	[5] = "spree5",
	[6] = "spree6",
	[7] = "spree7",
	[8] = "spree8",
	[9] = "spree9",
	[10] = "spree10",
	[11] = "spree10",
	[12] = "spree10",
	[13] = "spree10",
	[14] = "spree10",
	[15] = "spree15",	
}

-- multikill sounds filename table
local killSounds = {
	[2] = "kill2",
	[3] = "kill3",
	[4] = "kill4",
	[5] = "kill5",
}

-- bitwise and to compare flags
local function hasFlag(flags, flag)
	return bit.band(flags, flag) == flag
end

local onEvent = function(self, event, ...)
	self[event](self, event, ...)
end

local onUpdate = function(self, elapsed)
	soundUpdate = soundUpdate + elapsed
	if soundUpdate > 2 then
		soundUpdate = 0
		if nextSound then
			PlaySoundFile(self:getSoundFilePath(nextSound), "Master")
			nextSound = nil
		end
	end
end

PvPAnnouncers = CreateFrame("Frame")
PvPAnnouncers:SetScript("OnEvent", onEvent)
PvPAnnouncers:SetScript("OnUpdate", onUpdate)
PvPAnnouncers:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
PvPAnnouncers:RegisterEvent("ZONE_CHANGED_NEW_AREA")
PvPAnnouncers:RegisterEvent("PLAYER_DEAD")
	
-- #TODO remove this, add equivalent logic in COMBAT_LOG_EVENT_UNFILTERED
function PvPAnnouncers:PLAYER_DEAD()
	PlaySoundFile(self:getSoundFilePath("lose"), "Master")
	self:resetState()
end

function PvPAnnouncers:ZONE_CHANGED_NEW_AREA()
	if (self:isPvPZone(GetZoneText())) then
		PlaySoundFile(self:getSoundFilePath("startGame"), "Master")
		self:resetState()
	end
end

function PvPAnnouncers:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, auraType, ...)
	if eventType == "PARTY_KILL" and hasFlag(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and hasFlag(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) then
		local now = GetTime()
		if killTime + killResetTime > now then
			multiKill = multiKill + 1
		else
			multiKill = 1
		end
		if (UnitHealth("player") / UnitHealthMax("player") * 100 <= 25) and (UnitHealth("player") > 1) then
			PlaySoundFile(self:getSoundFilePath("smackDown"), "Master")
		end
		
		killTime = now
		killStreak = killStreak + 1
		
		self:PlaySounds()
	end
	-- Rage Quit on Paladin Divine Shield
	if eventType == "SPELL_CAST_SUCCESS" and hasFlag(sourceFlags, COMBATLOG_OBJECT_TARGET) and hasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) and spellName == "Divine Shield" then
		PlaySoundFile(self:getSoundFilePath("rageQuit"), "Master")
	end
	-- Rage Quit on Deserter
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(sourceFlags, COMBATLOG_OBJECT_TARGET) and hasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) and spellId == 26013 then
		PlaySoundFile(self:getSoundFilePath("rageQuit"), "Master")
	end
	-- Speed Buff
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and spellId == 23451 then
		PlaySoundFile(self:getSoundFilePath("powerUpSpeed"), "Master")
	end
	-- Damage Buff
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and spellId == 23505 then
		PlaySoundFile(self:getSoundFilePath("powerUpDamage"), "Master")
	end
	-- Regeneration Buff
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and spellId == 23493 then
		PlaySoundFile(self:getSoundFilePath("powerUpRegeneration"), "Master")
	end
	-- Invisibility Buff
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and spellId == 58984 and (self:isPvPZone(GetZoneText())) then
		PlaySoundFile(self:getSoundFilePath("powerUpInvisibility"), "Master")
	end
end

function PvPAnnouncers:PlaySounds()
	local multiKillFileName = killSounds[math.min(5, multiKill)]
	local killSpreeFileName = spreeSounds[math.min(15, killStreak)]
		
	if multiKillFileName then
		PlaySoundFile(self:getSoundFilePath(multiKillFileName), "Master")
	end
	
	if killSpreeFileName then
		local killSpreePath = self:getSoundFilePath(killSpreeFileName)

		if not multiKillFileName then
			PlaySoundFile(killSpreePath, "Master")
		else
			nextSound = killSpreePath
		end
	end
end

-- resets all local variables to their default state
function PvPAnnouncers:resetState()
	killStreak = 0
	multiKill = 0
end

-- get the correct sound file path for the selected announcer pack
function PvPAnnouncers:getSoundFilePath(fileName)
	return "Interface\\AddOns\\PvPAnnouncers\\sounds\\"..selectedAnnouncerPack.."\\"..fileName..".ogg"
end

-- checks if zone text is a PvP zone (arena, battleground, or world PvP zone)
function PvPAnnouncers:isPvPZone(zoneText)
	if (self:isArena(zoneText) or self:isBattleground(zoneText) or self:isWorldPvPZone(zoneText)) then
		return true
	else
		return false
	end
end

-- checks if zone text matches that of an arena
function PvPAnnouncers:isArena(zoneText)
	if (zoneText == "Nagrand Arena" or zoneText == "Blade's Edge Arena" or zoneText == "Ruins of Lordaeron" or zoneText == "Dalaran Arena" or zoneText == "Ring of Valor" or zoneText == "Tol'viron Arena" or zoneText == "The Tiger's Peak" or zoneText == "Black Rook Hold Arena" or zoneText == "Ashamane's Fall") then
		return true
	else
		return false
	end
end

-- checks if zone text matches that of a battleground
function PvPAnnouncers:isBattleground(zoneText)
	if (zoneText == "Warsong Gulch" or zoneText == "Silverwing Hold" or zoneText == "Warsong Lumber Mill" or zoneText == "Arathi Basin" or zoneText == "Alterac Valley" or zoneText == "Eye of the Storm" or zoneText == "Strand of the Ancients" or zoneText == "Twin Peaks" or zoneText == "The Battle for Gilneas" or zoneText == "Isle of Conquest" or zoneText == "Silvershard Mines" or zoneText == "Temple of Kotmogu" or zoneText == "Deepwind Gorge") then
		return true
	else
		return false
	end
end

-- checks if zoneText matches that of a world PvP zone
function PvPAnnouncers:isWorldPvPZone(zoneText)
	if (zoneText == "Wintergrasp" or zoneText == "Tol Barad" or zoneText == "Ashran") then
		return true
	else
		return false
	end
end