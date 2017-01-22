-- settings
local selectedAnnouncerPack = "HoN_Default"
local killResetTime = 15

-- locals
local killStreak = 0
local multiKill = 0
local killTime = 0
local soundUpdate = 0
local nextSoundSmackdownPath = nil
local nextSoundMultiKillPath = nil
local nextSoundKillSpreePath = nil

-- spellId constants
local deserterSpellId = 26013
local speedSpellId = 23451
local berserkingSpellId = 23505
local restorationSpellId = 23493
local shadowmeldSpellId = 58984
local invisibilitySpellId = 66
local greaterInvisibilitySpellId = 110959
local shroudOfConcealmentSpellId = 115834

-- debug
local debug = false

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
local multiKillSounds = {
	[2] = "kill2",
	[3] = "kill3",
	[4] = "kill4",
	[5] = "kill5",
}

-- bitwise and to compare flags
local function hasFlag(flags, flag)
	return bit.band(flags, flag) == flag
end

-- #TODO figure out why I need this
local onEvent = function(self, event, ...)
	self[event](self, event, ...)
end

-- plays second sound after a delay if both multi and spree were true
local onUpdate = function(self, elapsed)
	soundUpdate = soundUpdate + elapsed
	if soundUpdate > 2 then
		soundUpdate = 0
		
		-- plays the delayed multi kill sound
		if nextSoundMultiKillPath then
			PlaySoundFile(nextSoundMultiKillPath, "Master")
			
			if debug then
				print("next sound path")
				print(nextSoundMultiKillPath)
			end
			
			nextSoundMultiKillPath = nil
		else
			-- plays the delayed killing spree sound if there was no multi kill
			if nextSoundKillSpreePath then
				PlaySoundFile(nextSoundKillSpreePath, "Master")
			
				if debug then
					print("next sound path")
					print(nextSoundKillSpreePath)
				end
			
				nextSoundKillSpreePath = nil
			end
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

-- plays startGame sound upon entering a PvP zone
function PvPAnnouncers:ZONE_CHANGED_NEW_AREA()
	if (self:isPvPZone(GetZoneText())) then
		PlaySoundFile(self:getSoundFilePath("startGame"), "Master")
		self:resetState()
	end
end

-- main function
function PvPAnnouncers:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, auraType, ...)
	-- on pvp kill logic	
	if eventType == "PARTY_KILL" and hasFlag(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and (hasFlag(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) or debug) then
		local now = GetTime()
		
		-- check if kill occurred within multi kill time window
		if killTime + killResetTime > now then
			multiKill = multiKill + 1
		else
			multiKill = 1
		end
		
		-- smackdown if a kill is made when the player is below 25% health
		if (UnitHealth("player") / UnitHealthMax("player") * 100 <= 25) and (UnitHealth("player") > 1) then
			nextSoundSmackdownPath = self:getSoundFilePath("smackDown")
		end
		
		-- set kill time and increase streak by one
		killTime = now
		killStreak = killStreak + 1
		
		-- play relevant kill sounds
		self:PlaySounds()
	end
	
	-- Rage Quit on Paladin Divine Shield
	if eventType == "SPELL_CAST_SUCCESS" and hasFlag(sourceFlags, COMBATLOG_OBJECT_TARGET) and hasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) and spellName == "Divine Shield" then
		PlaySoundFile(self:getSoundFilePath("rageQuit"), "Master")
	end
	-- Rage Quit on Deserter
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(sourceFlags, COMBATLOG_OBJECT_TARGET) and hasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) and spellId == deserterSpellId then
		PlaySoundFile(self:getSoundFilePath("rageQuit"), "Master")
	end
	-- Speed Buff
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and spellId == speedSpellId then
		PlaySoundFile(self:getSoundFilePath("powerUpSpeed"), "Master")
	end
	-- Damage Buff
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and spellId == berserkingSpellId then
		PlaySoundFile(self:getSoundFilePath("powerUpDamage"), "Master")
	end
	-- Restoration Buff
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and spellId == restorationSpellId then
		PlaySoundFile(self:getSoundFilePath("powerUpRegeneration"), "Master")
	end
	-- Invisibility Buff
	if eventType == "SPELL_AURA_APPLIED" and hasFlag(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and ((spellId == shadowmeldSpellId) or (spellId == invisibilitySpellId) or (spellId == greaterInvisibilitySpellId) or (spellId == shroudOfConcealmentSpellId)) and (self:isPvPZone(GetZoneText())) then
		PlaySoundFile(self:getSoundFilePath("powerUpInvisibility"), "Master")
	end
end

-- plays multi and spree sounds
function PvPAnnouncers:PlaySounds()
	local multiKillFileName = multiKillSounds[math.min(5, multiKill)]
	local killSpreeFileName = spreeSounds[math.min(15, killStreak)]

	-- smackdown sound always take precedence
	if nextSoundSmackdownPath then
		PlaySoundFile(nextSoundSmackdownPath, "Master")
		
		if debug then
			print("smackdown path")
			print(nextSoundSmackdownPath)
		end
	end
	
	-- attempt to play the multi kill sound next
	if multiKillFileName then
		local multiKillPath = self:getSoundFilePath(multiKillFileName)
		
		-- if a smackdown was played, set this to be played later
		if nextSoundSmackdownPath then
			nextSoundMultiKillPath = multiKillPath
			
			if debug then
				print("next sound = multi kill path")
				print(nextSoundMultiKillPath)
			end
		-- otherwise play the sound right away
		else
			PlaySoundFile(multiKillPath, "Master")
	
			if debug then
				print("multi kill path")
				print(multiKillPath)
			end
		end
	end
	
	-- attempt to play the killing spree sound next
	if killSpreeFileName then
		local killSpreePath = self:getSoundFilePath(killSpreeFileName)
		
		-- if either smackdown or multi kill was played, set this to be played later
		if nextSoundSmackdownPath or multiKillFileName then
			nextSoundKillSpreePath = killSpreePath
		
			if debug then
				print("next sound = kill spree path")
				print(nextSoundKillSpreePath)
			end
		-- if neither smackdown nor multi kill was played, play the sound right away
		else		
			PlaySoundFile(killSpreePath, "Master")
			
			if debug then
				print("kill spree path")
				print(killSpreePath)
			end
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