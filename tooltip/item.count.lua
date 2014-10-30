local addonName, ns, _ = ...

-- ================================================
--  Item counts
-- ================================================
local locationLabels = { BAGSLOT, _G.BANK or 'Bank', VOID_STORAGE, AUCTIONS, BAG_FILTER_EQUIPMENT, MAIL_LABEL, REAGENT_BANK }
function ns.AddItemCounts(tooltip, itemID)
	local separator, showTotals, showGuilds, includeGuildCountInTotal = ', ', true, true, true -- TODO: config
	-- TODO: use only one line if item is unique
	-- local _, _, _, _, _, _, _, maxStack = GetItemInfo(itemID)

	local overallCount, numLines = 0, 0
	for _, character in ipairs(ns.data.GetCharacters()) do
		local baseCount, text = overallCount, nil
		for i, count in pairs( ns.data.GetItemCounts(character, itemID) ) do
			if count > 0 then
				overallCount = overallCount + count
				text = (text and text..separator or '') .. string.format('%s: %s%d|r', locationLabels[i], GREEN_FONT_COLOR_CODE, count)
			end
		end

		if overallCount - baseCount > 0 then
			tooltip:AddDoubleLine( ns.data.GetCharacterText(character) , text)
			numLines = numLines + 1
		end
	end
	if showGuilds then
		for guild, count in pairs( ns.data.GetGuildsItemCounts(itemID) ) do
			tooltip:AddDoubleLine(guild , string.format('%s: %s%d|r', GUILD_BANK, GREEN_FONT_COLOR_CODE, count))
			numLines = numLines + 1
			if includeGuildCountInTotal then
				overallCount = overallCount + count
			end
		end
	end
	if showTotals and numLines > 1 then
		tooltip:AddDoubleLine('  ', string.format('%s: %d', TOTAL, overallCount), nil, nil, nil, 1, 1, 1)
	end

	return numLines > 0
end
