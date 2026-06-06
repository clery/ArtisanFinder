local _, AF = ...

local function SetStatus(frame, text, isError)
	frame.status:SetText(text or "")
	frame.status:SetTextColor(isError and 1 or 0.4, isError and 0.25 or 1, isError and 0.2 or 0.4)
end

local function UpdateEditBoxHeight(frame)
	local text = frame.editBox:GetText() or ""
	frame.editBox:SetHeight(math.max(300, math.ceil(#text / 72) * 14 + 24))
end

local function SetTransferText(frame, text)
	frame.editBox:SetText(text or "")
	frame.editBox:SetCursorPosition(0)
	frame.editBox:HighlightText()
	frame.editBox:SetFocus()
	UpdateEditBoxHeight(frame)
	frame.scroll:SetVerticalScroll(0)
end

function AF:CreateTransferFrame()
	local frame = CreateFrame("Frame", "ArtisanFinderTransferFrame", UIParent, "ArtisanFinderTransferFrameTemplate")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	frame.title:SetText(self:Text("TRANSFER_TITLE"))
	frame.description:SetText(self:Text("TRANSFER_DESCRIPTION"))
	frame.export:SetText(self:Text("TRANSFER_EXPORT"))
	frame.import:SetText(self:Text("TRANSFER_IMPORT"))
	frame.clear:SetText(self:Text("TRANSFER_CLEAR"))
	frame.editBox = frame.scroll.editBox
	frame.editBox:SetMultiLine(true)
	frame.editBox:SetAutoFocus(false)
	frame.editBox:SetFontObject(ChatFontNormal)
	frame.editBox:SetScript("OnEscapePressed", function(box)
		box:ClearFocus()
	end)
	frame.editBox:SetScript("OnTextChanged", function()
		UpdateEditBoxHeight(frame)
	end)
	frame.scroll:SetScrollChild(frame.editBox)

	frame.export:SetScript("OnClick", function()
		local payload, errorMessage = AF:BuildArtisanTransferPayload()
		if not payload then
			SetStatus(frame, errorMessage, true)
			return
		end
		SetTransferText(frame, payload)
		SetStatus(frame, AF:Text("TRANSFER_EXPORT_READY", #payload), false)
	end)
	frame.import:SetScript("OnClick", function()
		local summary, errorMessage = AF:ImportArtisanTransferPayload(frame.editBox:GetText())
		if not summary then
			SetStatus(frame, errorMessage, true)
			return
		end
		SetStatus(frame, AF:Text(
			"TRANSFER_IMPORT_DONE",
			summary.addedArtisans,
			summary.mergedArtisans,
			summary.addedEntries,
			summary.updatedEntries,
			summary.skippedCurrent,
			summary.skippedInvalid
		), false)
	end)
	frame.clear:SetScript("OnClick", function()
		SetTransferText(frame, "")
		frame.editBox:ClearFocus()
		SetStatus(frame, self:Text("TRANSFER_READY"), false)
	end)

	self.transferFrame = frame
	return frame
end

function AF:OpenTransferFrame()
	local frame = self.transferFrame or self:CreateTransferFrame()
	SetStatus(frame, self:Text("TRANSFER_READY"), false)
	frame:Show()
	frame:Raise()
end
