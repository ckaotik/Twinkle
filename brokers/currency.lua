local addonName, addon, _ = ...

-- GLOBALS: _G, NORMAL_FONT_COLOR, LibStub, DataStore
-- GLOBALS: GetCurrencyInfo, ToggleCharacter, AbbreviateLargeNumbers, GetCurrencyListSize, GetCurrencyListInfo, GetCurrencyListLink, ExpandCurrencyList
-- GLOBALS: wipe, unpack, select, pairs, ipairs, strsplit, table, math, string, nop

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Currency')
local characters = {}

local defaults = {
	profile = {
		showInTooltip = {},
		showInLDB = {},
		iconFirst = true,
		showWeeklyInLDB = true,
	},
}

--[[
  TODO list:
  	- [config] currency order: [drag handle] [icon] currency name 	[x:ldb] [x:tooltip]
--]]

local function GetGeneralCurrencyInfo(currencyID)
	-- FIXME: for some reason, max counts are not available for undiscovered currencies
	local name, _, texture, _, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(currencyID)
	if currencyID == 824 then
		-- garrison resource: display uncollected as weekly
		weeklyMax = 500
	elseif currencyID == 1129 then
		-- seal of inevitable fate
		weeklyMax = 3
	end
	return name, texture, totalMax, weeklyMax
end

local collapsed = {}
local function ScanCurrencies()
	local index = 1
	while index <= GetCurrencyListSize() do
		local name, isHeader, isExpanded, _, isWatched, count, icon, maximum, hasWeeklyLimit = GetCurrencyListInfo(index)
		if isHeader and not isExpanded then
			table.insert(collapsed, index)
			ExpandCurrencyList(index, true)
		elseif not isHeader then
			local link = GetCurrencyListLink(index)
			local currencyID = link and link:match('currency:(%d+)') * 1
			if currencyID then
				if broker.db.profile.showInLDB[currencyID] == nil then
					-- new currency found, add to settings
					broker.db.profile.showInLDB[currencyID] = isWatched
					broker.db.profile.showInTooltip[currencyID] = isWatched
				end
			end
		end
		index = index + 1
	end
	-- restore collapsed states
	for index = #collapsed, 1, -1 do
		ExpandCurrencyList(index, false)
		collapsed[index] = nil
	end
end

local sortCurrency, sortCurrencyReverse = 0, false
local function Sort(a, b)
	local valueA, valueB
	if sortCurrency == 0 then
		valueA, valueB = addon.data.GetName(a), addon.data.GetName(b)
	else
		local _, _, countA, _, weeklyA = addon.data.GetCurrencyInfo(a, sortCurrency)
		local _, _, countB, _, weeklyB = addon.data.GetCurrencyInfo(b, sortCurrency)
		valueA = sortCurrency < 0 and weeklyA or countA
		valueB = sortCurrency < 0 and weeklyB or countB
	end
	if sortCurrencyReverse then
		return valueA > valueB
	else
		return valueA < valueB
	end
end

local function ChangeSort(self, sortType, btn, up)
	if sortCurrency == sortType then
		sortCurrencyReverse = not sortCurrencyReverse
	else
		sortCurrency = sortType
		sortCurrencyReverse = false
	end
	broker:Update()
end

-- --------------------------------------------------------
--  Setup LDB
-- --------------------------------------------------------
function broker:OnEnable()
	self.db = addon.db:RegisterNamespace('Currency', defaults)

	-- Purge removed currencies.
	for currencyID, enabled in pairs(self.db.profile.showInLDB) do
		local name, _, _, _, _, count, icon = GetCurrencyInfo(currencyID)
		if name == '' and not icon and count == 0 then
			self.db.profile.showInLDB[currencyID] = nil
		end
	end
	for currencyID, enabled in pairs(self.db.profile.showInTooltip) do
		local name, _, _, _, _, count, icon = GetCurrencyInfo(currencyID)
		if name == '' and not icon and count == 0 then
			self.db.profile.showInTooltip[currencyID] = nil
		end
	end

	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', self.Update, self)
	self:RegisterEvent('SHOW_LOOT_TOAST', function(self, event, lootType, link, quantity, specID, sex, isPersonal, lootSource)
		if lootSource == 10 then -- garrison cache
			self:Update()
		end
	end, self)

	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('CURRENCY_DISPLAY_UPDATE')
end

function broker:OnClick(btn, down)
	if btn == 'RightButton' then
		InterfaceOptionsFrame_OpenToCategory(addonName)
	else
		ToggleCharacter('TokenFrame')
	end
end

function broker:UpdateLDB()
	ScanCurrencies()

	local characterKey, currenciesString = addon.data.GetCurrentCharacter(), nil
	for currencyID, isShown in pairs(broker.db.profile.showInLDB) do
		if isShown then
			local _, name, total, icon, weekly = addon.data.GetCurrencyInfo(characterKey, currencyID)
			local _, _, totalMax, weeklyMax = GetGeneralCurrencyInfo(currencyID)

			local text = AbbreviateLargeNumbers(total)
			if totalMax > 0 then
				text = addon.ColorizeText(text, 1 - (total / totalMax))
			end
			if broker.db.profile.showWeeklyInLDB and weeklyMax and weekly > 0 then
				local weeklyIcon = '' -- '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t'
				local weeklyText = addon.ColorizeText(AbbreviateLargeNumbers(weekly), 1 - (weekly / weeklyMax))
				text = ('%s (%s%s)'):format(text, weeklyIcon, weeklyText)
			end

			if broker.db.profile.iconFirst then
				text = '|T'..icon..':0|t ' .. text
			else
				text = text .. ' |T'..icon..':0|t'
			end
			currenciesString = (currenciesString and currenciesString .. ' ' or '') .. text
		end
	end

	self.text = currenciesString
	self.icon = 'Interface\\Minimap\\Tracking\\BattleMaster'
end

function broker:UpdateTooltip()
	self:SetColumnLayout(1, 'LEFT')
	local lineNum, column = self:AddHeader(_G.CHARACTER), 2
	-- sort by character name
	self:SetCellScript(lineNum, 1, 'OnMouseUp', ChangeSort, 0)
	for currencyID, isShown in pairs(broker.db.profile.showInTooltip) do
		if isShown then
			local name, texture, totalMax, weeklyMax = GetGeneralCurrencyInfo(currencyID)
			if column > #self.columns then column = self:AddColumn('RIGHT') end
			self:SetCell(lineNum, column, texture and '|T'..texture..':0|t' or name)
			self.lines[lineNum].cells[column].link = 'currency:'..currencyID
			self:SetCellScript(lineNum, column, 'OnEnter', addon.ShowTooltip, self)
			self:SetCellScript(lineNum, column, 'OnLeave', addon.HideTooltip, self)
			self:SetCellScript(lineNum, column, 'OnMouseUp', ChangeSort, currencyID)
			column = column + 1

			if weeklyMax and weeklyMax > 0 then
				if column > #self.columns then column = self:AddColumn('RIGHT') end
				self:SetCell(lineNum, column, '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t')
				self:SetCellScript(lineNum, column, 'OnMouseUp', ChangeSort, -1*currencyID)
				column = column + 1
			end
		end
	end
	self:AddSeparator(2)

	addon.data.GetCharacters(characters)
	table.sort(characters, Sort)

	local addLine = true
	for _, characterKey in ipairs(characters) do
		if addLine then lineNum = self:AddLine(); addLine = false end
		self:SetCell(lineNum, 1, addon.data.GetCharacterText(characterKey))
		self:SetLineScript(lineNum, 'OnEnter', nop) -- show highlight on row

		local column = 2
		for currencyID, isShown in pairs(broker.db.profile.showInTooltip) do
			-- FIXME: this can lead to incorrect assignment due to order
			if isShown then
				local _, name, total, _, weekly = addon.data.GetCurrencyInfo(characterKey, currencyID)
				addLine = addLine or ((total or 0) > 0 or (weekly or 0) > 0)

				local _, _, totalMax, weeklyMax = GetGeneralCurrencyInfo(currencyID)
				local text = AbbreviateLargeNumbers(total)
				if totalMax > 0 then
					text = addon.ColorizeText(text, 1 - (total / totalMax))
				end
				self:SetCell(lineNum, column, text, 'RIGHT')
				column = column + 1

				if weeklyMax and weeklyMax > 0 then
					text = addon.ColorizeText(AbbreviateLargeNumbers(weekly), 1 - (weekly / weeklyMax))
					self:SetCell(lineNum, column, text, 'RIGHT')
					column = column + 1
				end
			end
		end
	end

	if addLine then lineNum = self:AddLine() end
	self:SetCell(lineNum, 1, _G.GRAY_FONT_COLOR_CODE..'Left click: open token frame'..'|r', 'LEFT', #self.columns)
end
