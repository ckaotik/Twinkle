local addonName, ns, _ = ...

local characters = ns.data.GetCharacters()

-- ================================================
--  Recipes
-- ================================================
local recipeKnownCharacters, recipeUnknownCharacters = {}, {}
local function SortByName(a, b)
	local nameA = a:gsub('|c........', ''):gsub('|r', '')
	local nameB = b:gsub('|c........', ''):gsub('|r', '')
	return nameA < nameB
end
local function SortBySkill(a, b)
	local skillA = a:match("%((.-)%)") or math.huge
	local skillB = b:match("%((.-)%)") or math.huge
	if skillA ~= skillB then
		return tonumber(skillA) > tonumber(skillB)
	else
		return SortByName(a, b)
	end
end
local function GetRecipeKnownInfo(craftedName, professionName, requiredSkill)
	local onlyUnknown = false -- TODO: config

	wipe(recipeKnownCharacters)
	wipe(recipeUnknownCharacters)
	if not DataStore:GetMethodOwner('GetProfession') or not DataStore:GetMethodOwner('GetProfessionInfo') or not DataStore:GetMethodOwner('GetCraftLineInfo') or not DataStore:GetMethodOwner('GetNumCraftLines') then
		return recipeKnownCharacters, recipeUnknownCharacters
	end

	local selfKnown = nil
	for _, character in ipairs(characters) do
		local profession = DataStore:GetProfession(character, professionName)
		if profession then
			local numCrafts = DataStore:GetNumCraftLines(profession)
			local isKnown = nil
			for i = 1, numCrafts do
				local isHeader, _, spellID = DataStore:GetCraftLineInfo(profession, i)
				if not isHeader then
					local skillName = GetSpellInfo(spellID) or ""
					if skillName == craftedName then
						isKnown = true
						break
					end
				end
			end

			if isKnown and character == thisCharacter then
				selfKnown = true
			end

			local charName = ns.data.GetCharacterText(character)
			if isKnown and not onlyUnknown then
				table.insert(recipeKnownCharacters, charName)
			elseif not isKnown and numCrafts > 0 then
				local skillLevel = DataStore:GetProfessionInfo(profession)
				--[[ local learnableColor = (not requiredSkill and HIGHLIGHT_FONT_COLOR_CODE)
					or (skillLevel >= requiredSkill and GREEN_FONT_COLOR_CODE)
					or RED_FONT_COLOR_CODE --]]

				local characterText
				if not requiredSkill or skillLevel >= requiredSkill then
					characterText = charName
				else
					characterText = string.format("%s %s(%d)|r", charName, RED_FONT_COLOR_CODE, skillLevel)
				end
				-- local characterText = string.format("%s %s(%d)|r", charName, learnableColor, skillLevel)
				table.insert(recipeUnknownCharacters, characterText)
			end
		end
	end
	table.sort(recipeKnownCharacters, SortByName)
	table.sort(recipeUnknownCharacters, SortBySkill)
	return recipeKnownCharacters, recipeUnknownCharacters, selfKnown
end

function ns.AddCraftInfo(tooltip, professionName, craftedName, requiredSkill)
	local onlyUnknown = false -- TODO: config
	local linesAdded = false
	local known, unknown, selfKnown = GetRecipeKnownInfo(craftedName, professionName, requiredSkill)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		if selfKnown then
			-- don't show duplicate ITEM_SPELL_KNOWN line
			local line, text
			for lineNum = tooltip:NumLines(), 1, -1 do
				line = _G[tooltip:GetName().."TextLeft"..lineNum]
				text = line:GetText()
				if text and text == ITEM_SPELL_KNOWN then
					line:SetText(nil)
					break
				end
			end
		end

		tooltip:AddLine(RED_FONT_COLOR_CODE..ITEM_SPELL_KNOWN..": "..FONT_COLOR_CODE_CLOSE..list, 1, 1, 1, true)
		linesAdded = true
	end

	list = table.concat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(GREEN_FONT_COLOR_CODE..UNKNOWN..": "..FONT_COLOR_CODE_CLOSE..list, 1, 1, 1, true)
		linesAdded = true
	end
	return linesAdded
end
