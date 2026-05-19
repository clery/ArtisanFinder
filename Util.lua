local addonName, AF = ...

_G.ArtisanFinder = AF

AF.ADDON_NAME = addonName
AF.PREFIX = "ARTFIND1"
AF.PROTOCOL_VERSION = "1"
AF.CHANNEL_NAME = "ArtisanFinder"
AF.CACHE_MAX_AGE = 14 * 24 * 60 * 60
AF.RESPONSE_THROTTLE = 60
AF.DETAIL_REQUEST_THROTTLE = 30
AF.REAGENT_DETAIL_CACHE_MAX_AGE = 60 * 60
AF.LIVE_QUERY_TIMEOUT = 6
AF.MAX_NOTE_CHARS = 256
AF.MAX_NOTE_BYTES = 1024
AF.MAX_COMMISSION_GOLD = 99999999
AF.MAX_COMMISSION_COPPER = AF.MAX_COMMISSION_GOLD * 10000
AF.MAX_LINK_BYTES = 96
AF.SCHEMA_VERSION = 9

function AF:Print(message)
	print("|cff33ff99ArtisanFinder:|r " .. tostring(message))
end

local TRADE_CHANNEL_PATTERNS = {
	"trade",
	"commerce",
	"comercio",
	"handel",
	"торгов",
	"торг",
	"交易",
	"貿易",
}

function AF:IsTradeChannelName(name)
	name = tostring(name or ""):lower()
	if name == "" then
		return false
	end
	for _, pattern in ipairs(TRADE_CHANNEL_PATTERNS) do
		if name:find(pattern, 1, true) then
			return true
		end
	end
	return false
end

function AF:IsInUnavailableActivity()
	if C_PartyInfo.IsDelveInProgress() then
		return true
	end
	if not IsInInstance then
		return false
	end
	local inInstance, instanceType = IsInInstance()
	if not inInstance then
		return false
	end
	return instanceType == "party"
		or instanceType == "raid"
		or instanceType == "pvp"
		or instanceType == "arena"
end

function AF:ApplyProfessionPanel(frame)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.02, 0.018, 0.014, 0.82)
	frame:SetBackdropBorderColor(0.62, 0.51, 0.27, 0.9)
end

function AF:ApplyCustomerSidePanel(frame)
	frame.Bg:SetAtlas("auctionhouse-background-index", false)
	frame.Bg:ClearAllPoints()
	frame.Bg:SetPoint("TOPLEFT", 6, -21)
	frame.Bg:SetPoint("BOTTOMRIGHT", -2, 2)
	frame.TopTileStreaks:Hide()
end

function AF:ApplyCustomerListInset(frame)
	if not frame.Background then
		frame.Background = frame:CreateTexture(nil, "BACKGROUND")
		frame.Background:SetAtlas("auctionhouse-background-index", false)
		frame.Background:SetPoint("TOPLEFT", 3, 0)
		frame.Background:SetPoint("BOTTOMRIGHT", -30, 0)
	end

	if not frame.NineSlice then
		frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
		frame.NineSlice:SetPoint("TOPLEFT", 0, 0)
		frame.NineSlice:SetPoint("BOTTOMRIGHT", -27, 0)
		frame.NineSlice:SetFrameLevel(frame:GetFrameLevel())
		frame.NineSlice.layoutType = "InsetFrameTemplate"
		if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
			NineSliceUtil.ApplyLayoutByName(frame.NineSlice, frame.NineSlice.layoutType)
		end
	end
end

function AF:ApplyCustomerPopupPanel(frame)
	if not frame.Background then
		frame.Background = frame:CreateTexture(nil, "BACKGROUND")
	end
	frame.Background:SetAtlas("auctionhouse-background-index", false)
	frame.Background:ClearAllPoints()
	frame.Background:SetPoint("TOPLEFT", 3, -3)
	frame.Background:SetPoint("BOTTOMRIGHT", -3, 3)

	if not frame.NineSlice then
		frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
		frame.NineSlice:SetPoint("TOPLEFT", 0, 0)
		frame.NineSlice:SetPoint("BOTTOMRIGHT", 0, 0)
		frame.NineSlice:SetFrameLevel(frame:GetFrameLevel())
		frame.NineSlice.layoutType = "InsetFrameTemplate"
		if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
			NineSliceUtil.ApplyLayoutByName(frame.NineSlice, frame.NineSlice.layoutType)
		end
	end

	if not frame.TopDivider then
		frame.TopDivider = frame:CreateTexture(nil, "ARTWORK")
		frame.TopDivider:SetAtlas("Options_HorizontalDivider", true)
		frame.TopDivider:SetPoint("TOPLEFT", 10, -5)
		frame.TopDivider:SetPoint("TOPRIGHT", -10, -5)
		frame.TopDivider:SetHeight(2)
		frame.TopDivider:SetAlpha(0.35)
	end
end

function AF:StyleListRow(row)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	local highlight = row:GetHighlightTexture()
	if highlight then
		highlight:SetAlpha(0.28)
	end
	row.divider = row:CreateTexture(nil, "BORDER")
	row.divider:SetAtlas("Options_HorizontalDivider", true)
	row.divider:SetPoint("BOTTOMLEFT", 4, 0)
	row.divider:SetPoint("BOTTOMRIGHT", -4, 0)
	row.divider:SetHeight(2)
	row.divider:SetAlpha(0.35)
end

function AF:AddDivider(parent, anchor, offsetY)
	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -6)
	divider:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
	divider:SetHeight(2)
	divider:SetAlpha(0.45)
	return divider
end

function AF:Now()
	return time()
end

function AF:IsInCombatLocked()
	return InCombatLockdown and InCombatLockdown() == true
end


function AF:OpenWhisper(target, message)
	target = self:NormalizeName(target)
	if not target then
		return
	end
	ChatFrame_OpenChat("/w " .. target .. " " .. (message or ""), DEFAULT_CHAT_FRAME)
end
