local _, AF = ...

AF.L = AF.L or {}
local L = AF.L

L.ADDON_LOADED = "loaded. Crafter availability is off for this session."
L.AVAILABILITY_CHANGED = "crafter availability %s."
L.ENABLED = "enabled"
L.DISABLED = "disabled"
L.EVENT_UNAVAILABLE = "skipping unavailable event %s."
L.MINIMAP_LIBS_MISSING = "minimap libraries were not available."

L.FREE_COMMISSION = "Free commission"
L.NO_PRICE_SET = "No price set"
L.BASE_QUALITY = "Base %s"
L.RECOMMENDED_REAGENTS_QUALITY = "Recommended reagents %s"
L.SUGGESTED_REAGENTS = "Suggested reagents"
L.LOADING_REAGENT_NAMES = "Loading reagent names..."
L.NO_REAGENT_RECOMMENDATION = "No reagent recommendation is available for this recipe."
L.ITEM_FALLBACK = "Loading item"
L.PROFESSION_FALLBACK = "Profession %s"
L.CERTIFIED_ADDON_DATA = "Certified addon data"
L.MISSING_ADDON_DATA = "Missing addon data for accurate qualities"

L.SORT_RECOMMENDED = "Recommended"
L.SORT_COMMISSION = "Commission"
L.SORT_QUALITY = "Quality"
L.SORT_BUTTON = "Sort: %s"
L.SELECT_ORDER_ITEM = "Select an order item."
L.AVAILABLE_ARTISANS_FOR = "Available artisans for %s"
L.DEBUG_NOT_SCANNED = "Debug on, but this character has not scanned %s."
L.NO_FILTER_MATCH = "No available artisans match the filter for %s."
L.CHECKING_ARTISANS = "Checking available artisans for %s..."
L.NO_ARTISANS_FOUND = "No available artisans found for %s."
L.WHISPER = "Whisper"
L.PERSONAL_ORDER = "Personal Order"
L.PROFESSION = "Profession"
L.REFRESH = "Refresh"
L.DEBUG_CRAFTER = "Debug crafter"
L.DEBUG_SUFFIX = "Debug %d"
L.PERSONAL_ORDER_NO_FORM = "open a customer order before filling a personal order."
L.PERSONAL_ORDER_FILLED = "filled personal order fields. Please review before placing the order."

L.ITEM_SPECIFIC_COMMISSION = "Item-specific commission"
L.ITEM_SPECIFIC_TOOLTIP = "These fields apply only to the selected craft and override the profession default when specified."
L.DEFAULT_COMMISSION = "Default commission"
L.DEFAULT_COMMISSION_TOOLTIP = "These fields apply to crafts in the current profession when no item-specific commission is specified."
L.COMMISSION = "Commission"
L.NOTE = "Note"
L.SAVE = "Save"
L.COMMISSION_HELP_0 = "0: unspecified."
L.COMMISSION_HELP_FREE = "-1: free commission."
L.COMMISSION_HELP_POSITIVE = "Positive value: gold commission."
L.COMMISSION_INVALID = "enter 0 for unspecified, -1 for free commission, or a positive gold value."
L.SELECT_LEARNED_CRAFT = "select a learned craft before saving item pricing."
L.OPEN_PROFESSION_DEFAULT = "open a profession before saving a default price."

L.SCAN_OPEN_PROFESSION = "open a profession and wait for it to finish loading before scanning."
L.SCAN_NO_PROFESSION = "could not identify the current profession."
L.SCAN_NO_RECIPES = "no recipes were available to scan."
L.SCAN_STARTED = "scanning %s in the background."
L.SCAN_COMPLETE = "scanned %d craftable item entries for %s."
L.SCAN_RESUMED = "resuming %s scan in the background."
L.SCAN_PAUSED = "paused %s scan with %d item entries remaining. Reopen the profession to resume."
L.SCAN_WAITING_KNOWLEDGE = "waiting for %s knowledge changes to apply before scanning."
L.SCAN_HELP_FORCE = "/af scan - force a fresh scan of the currently open profession"
L.RECIPE_FALLBACK = "Recipe %s"

L.MINIMAP_AVAILABLE = "Available this session"
L.MINIMAP_UNAVAILABLE = "Unavailable this session"
L.MINIMAP_SCANNED = "Scanned items: %d"
L.MINIMAP_LEFT_CLICK = "Left-click: toggle availability"
L.MINIMAP_RIGHT_CLICK = "Right-click: open profession panel"

L.DEBUG_SELF_CHANGED = "debug self results %s."
L.DEBUG_SELF_STATE = "debug self results are %s."
L.DEBUG_UNKNOWN = "unknown debug command: %s"
L.DEBUG_HELP_ON = "/af debug on - show this character in customer results when scanned"
L.DEBUG_HELP_OFF = "/af debug off - disable debug self results"
L.DEBUG_HELP_TOGGLE = "/af debug toggle - toggle debug self results"
L.DEBUG_HELP_STATE = "/af debug - show current debug state"

function AF:Text(key, ...)
	local text = self.L and self.L[key] or key
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end
