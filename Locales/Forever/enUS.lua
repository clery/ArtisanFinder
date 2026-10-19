local _, AF = ...
local L = AF.Locales.enUS

L.FOREVER_HISTORICAL = "Historical"
L.CLEAR_HELP_SCANS = "/af clear scans [First Last] - clear scanned crafts for this character or a player’s full name"
L.FOREVER_ARTISAN = "Artisan"
L.FOREVER_PROFESSION = "Profession"
L.FOREVER_DISCOVERED_BY = "Discovered by"
L.FOREVER_LAST_OBSERVED = "Last observed"
L.FOREVER_SOURCE_TRADE = "Trade offer"
L.FOREVER_SOURCE_GUILD = "Guild"
L.FOREVER_SOURCE_ADDON = "ArtisanFinder"
L.FOREVER_ALL = "All"
L.FOREVER_PREVIOUS = "Previous page"
L.FOREVER_NEXT = "Next page"
L.FOREVER_ARTISAN_COUNT = "%d artisans"
L.FOREVER_DIRECTORY_EMPTY = "No artisans found. Try another item or broaden your filters."
L.FOREVER_JUST_NOW = "just now"
L.FOREVER_MINUTES_AGO = "%d min ago"
L.FOREVER_PAGE = "Page %d / %d · %d artisans"
L.FOREVER_ITEM_NOT_FOUND = "No matching known item. Paste an item link, enter its ID, or drag the item here."
L.FOREVER_CHOOSE_ITEM = "Choose an item"
L.FOREVER_MINIMAP_OPEN = "Left-click: open artisan directory"
L.FOREVER_MINIMAP_AVAILABILITY = "Ctrl-left-click: cycle availability"
L.SELECT_ORDER_ITEM = "Search by item name, ID or link, or drag an item into the search field."
L.PROFESSION_LINK = "View profession"

L.FOREVER_INDICATORS = "Profession indicators"
L.FOREVER_INDICATORS_ENABLED = "Show profession icons above friendly players"
L.FOREVER_INDICATORS_SIZE = "Icon size"
L.FOREVER_INDICATORS_OFFSET = "Vertical offset"

L.CHANGELOG_ENTRY_FOREVER_2_1_5 = [[### Added
- Find crafters by artisan, profession or item name, including linked alts. Search with an item link or drag an item into discovery.
- Discover crafters using Linked Inn, CraftBoard and Release Gaming – Find Crafts alongside ArtisanFinder, guild members and Trade Chat offers.
- Track the materials for a craft in your quest objectives and search for missing materials with Auctionator.

### Changed
- Browse an expandable artisan directory with profession levels, known recipes, commissions and notes. Filter and sort results, keep favorites first, and open profession links or whisper crafters directly.]]

L.CHANGELOG_ENTRY_FOREVER_2_1_4 = [[### Added
- Find artisans in a standalone directory with search, favorites and profession links.
- Manage profession and recipe commissions, notes and availability from the crafting window.
- Advertise scanned professions across your characters and import or export artisan profiles.
- Identify nearby crafters through profession icons above friendly players.]]

L.FOREVER_DEMO_HELP = "/af demo [on|off] - preview profession icons on a friendly target or yourself for five minutes."
L.FOREVER_DEMO_STARTED = "Demo icons enabled for %s for five minutes. Icons appear outside combat and instances. Use /af demo off to stop."
L.FOREVER_DEMO_STOPPED = "Nameplate demo stopped."
L.FOREVER_DEMO_NO_NAME = "No player name available for the nameplate demo."

L.FOREVER_PRICE = "Price"
L.FOREVER_PRICE_ITEM = "Item commission"
L.FOREVER_PRICE_DEFAULT = "Profession default"
L.FOREVER_PRICE_UNKNOWN = "Commission not shared. Contact the artisan for a quote."

L.FOREVER_NO_KNOWN_CRAFTS = "No shared crafts known yet."
L.FOREVER_NO_DEFAULT_NOTE = "No default note shared."
L.FOREVER_RECIPE_ID = "Recipe #%d"

L.FOREVER_SEARCH_ALL = "Search artisans, professions or items"
L.FOREVER_SEARCH_ALL_HELP = "Filter by artisan, profession or known item name. Press Enter to query an exact item name, item ID or link, or drag an item here."

L.FOREVER_COIN_GOLD = "Gold"
L.FOREVER_COIN_SILVER = "Silver"
L.FOREVER_COIN_COPPER = "Copper"
L.FOREVER_COIN_HELP = "Enter whole coins in each field (0–99 silver and copper). Leave all fields empty to use no fixed commission or inherit the profession default. Enter -1 in Gold for any commission."

L.COMMISSION_HELP_POSITIVE = "Set the commission in gold, silver and copper. Silver and copper range from 0 to 99."
L.COMMISSION_HELP_FREE = "Enter -1 in the Gold field: any commission."
L.COMMISSION_INVALID = "Enter whole gold, silver and copper amounts (0–99 silver and copper), or -1 Gold for any commission."

L.FOREVER_SORT = "Sort discovery"
L.FOREVER_SORT_HINT = "Click to sort by this column. Click again to reverse the order."

L.FOREVER_TRACK_MATERIALS = "Track materials"

L.FOREVER_TRACK_MATERIALS_HELP = "Track the materials for this craft in the quest objectives. At the auction house, search missing materials with Auctionator."

L.FOREVER_MATERIALS_UNAVAILABLE = "Material requirements are unavailable. Open the crafter’s profession link or scan the recipe, then try again."

L.FOREVER_HOURS_AGO = "%d hr ago"

L.FOREVER_DAYS_AGO = "%d d ago"

L.FOREVER_MONTHS_AGO = "%d mo ago"

L.FOREVER_YEARS_AGO = "%d yr ago"

L.FOREVER_DISCOVERY_OPTIONS = "Discovery"
L.OPTIONS_SHOW_OWN_CHARACTER_ROWS_DESC = "Include your current character in discovery when they can craft a matching item."

L.FOREVER_SHOW_FRIENDLY_NAMES = "Show friendly player names"
L.FOREVER_FRIENDLY_NAMES_QUESTION = "Would you like to see friendly player names alongside ArtisanFinder profession icons? You can change this later in ArtisanFinder settings."

L.FOREVER_ADVERTISE_PROFESSION = "Advertise this profession"
L.FOREVER_ADVERTISE_PROFESSION_HELP = "Toggle advertising for this profession in ArtisanFinder."

L.FOREVER_TUTORIAL_SEARCH = "Search by artisan, profession or known item. Press Enter to query an item name, ID or link, or drag an item into the search field."
L.FOREVER_TUTORIAL_HEADERS = "Use the filter icons to choose professions and discovery sources. Click Artisan, Discovered by, Price or Last observed to sort; click again to reverse the order. Favorites stay first."
L.FOREVER_TUTORIAL_ROWS = "Click an artisan to reveal professions and skill levels, then a profession to reveal known crafts. Hover for notes and actions. Use the star for favorites, the profession link or whisper action to contact the crafter, and Track materials on a craft to create a checklist. Prices use profession defaults unless an item has its own commission."
L.FOREVER_TUTORIAL_PAGES = "Use these arrows to change artisan pages. Scroll inside the table to see expanded professions and crafts."
L.FOREVER_TUTORIAL_RESET = "Tutorials reset. Open discovery or a profession to see the guide again. The information icons always reopen help."

L.FOREVER_TUTORIAL_END_HINT = "Click this information icon again to end the tutorial."

-- Private crafting agreements
L.AGREEMENT_TITLE = "Crafting agreements"
L.AGREEMENT_TOAST_TITLE = "Crafting agreement"
L.AGREEMENT_REQUEST = "Request this craft"
L.AGREEMENT_SLASH_HELP = "/af agreements - open private crafting agreements"
L.AGREEMENT_INCOMING = "Incoming"
L.AGREEMENT_OUTGOING = "Outgoing"
L.AGREEMENT_DRAFT = "Unsent draft"
L.AGREEMENT_PENDING = "Pending"
L.AGREEMENT_COUNTEROFFERED = "Counteroffer"
L.AGREEMENT_ACCEPTED = "Accepted"
L.AGREEMENT_COMPLETED = "Completed"
L.AGREEMENT_DECLINED = "Declined"
L.AGREEMENT_CANCELLED = "Cancelled"
L.AGREEMENT_EXPIRED = "Expired"
L.AGREEMENT_AWAITING_CONFIRMATION = "Awaiting completion confirmation"
L.AGREEMENT_WAITING_DELIVERY = "Awaiting delivery confirmation"
L.AGREEMENT_CONTACT = "Contact: %s"
L.AGREEMENT_CRAFTING_CHARACTER = "Crafting character: %s"
L.AGREEMENT_QUANTITY = "Craft operations"
L.AGREEMENT_TOTAL_COMMISSION = "Total commission (blank = unspecified)"
L.AGREEMENT_MESSAGE = "Optional message"
L.AGREEMENT_MATERIALS = "Materials · owned / required · missing"
L.AGREEMENT_MATERIAL_UNKNOWN = "? / %d · missing unknown"
L.AGREEMENT_MATERIAL_LINE = "%s · %d / %d · %d missing"
L.AGREEMENT_MORE_MATERIALS = "+ %d materials (hover to see all)"
L.AGREEMENT_OUTPUT = "Result: %d–%d items"
L.AGREEMENT_DRAFT_HELP = "An agreement records intentions only. Crafting, trading and payment remain manual. Zero commission means free."
L.AGREEMENT_UNSUPPORTED = "Support is not confirmed. Sending saves an unsent draft; you can whisper the artisan instead."
L.AGREEMENT_UNKNOWN_CRAFT = "Unknown craft"
L.AGREEMENT_EMPTY = "No agreements in this list."
L.AGREEMENT_LIST_COUNT = "%d agreements · scroll to browse"
L.AGREEMENT_NOTIFICATION = "Crafting agreement updated: %s"
L.AGREEMENT_QUANTITY_ERROR = "Enter 1–999 craft operations."
L.AGREEMENT_PRICE_ERROR = "Enter a valid total commission within the allowed limit."
L.AGREEMENT_ACTION_ERROR = "This action could not be completed. Check the agreement and try again."
L.AGREEMENT_RESTRICTED = "Cannot send here while addon messages are restricted. Your draft is saved; try again after leaving the restricted activity."
L.AGREEMENT_CAPACITY_ERROR = "You already have 50 active outgoing agreements. Complete or cancel an agreement before sending another."
L.AGREEMENT_INVALID_ERROR = "This draft has invalid craft details or message text. Use a known craft, a different recipient, and a message of up to 256 characters without links."
L.AGREEMENT_SCHEMA_ERROR = "These agreements were saved by a newer addon version. Update ArtisanFinder before sending."
L.AGREEMENT_MATERIALS_ERROR = "Material details are unavailable for this craft."
L.AGREEMENT_SEND = "Send request"
L.AGREEMENT_ACCEPT = "Accept these terms"
L.AGREEMENT_DECLINE = "Decline agreement"
L.AGREEMENT_COUNTER = "Send counteroffer with this total commission and message"
L.AGREEMENT_CANCEL = "Cancel agreement"
L.AGREEMENT_COMPLETE = "Declare or confirm completion"
L.AGREEMENT_TRACK = "Track required materials"
L.AGREEMENT_RETRY = "Retry delivery and reconcile the latest state"
L.AGREEMENT_WHISPER = "Whisper contact"
L.AGREEMENT_IGNORE = "Ignore future requests from this player"
L.AGREEMENT_DELETE = "Delete this local record"
L.AGREEMENT_IGNORED = "Ignored request senders"
L.AGREEMENT_NO_IGNORED = "No ignored players."
L.AGREEMENT_UNIGNORE = "Allow requests from %s"
L.AGREEMENT_DELIVERY_FAILED = "Delivery failed — retry available"

-- Labeled agreement actions
L.AGREEMENT_BUTTON_SEND = "Send request"
L.AGREEMENT_BUTTON_ACCEPT = "Accept terms"
L.AGREEMENT_BUTTON_DECLINE = "Decline"
L.AGREEMENT_BUTTON_COUNTER = "Counteroffer"
L.AGREEMENT_BUTTON_CANCEL = "Cancel agreement"
L.AGREEMENT_BUTTON_COMPLETE = "Declare completion"
L.AGREEMENT_BUTTON_TRACK = "Track materials"
L.AGREEMENT_BUTTON_RETRY = "Retry delivery"
L.AGREEMENT_BUTTON_WHISPER = "Whisper"
L.AGREEMENT_BUTTON_IGNORE = "Ignore player"
L.AGREEMENT_BUTTON_DELETE = "Delete record"
L.AGREEMENT_BUTTON_IGNORED = "Ignored players"
L.AGREEMENT_BUTTON_PREVIOUS = "Previous"
L.AGREEMENT_BUTTON_NEXT = "Next"
L.AGREEMENT_BUTTON_CONFIRM = "Confirm completion"

L.FOREVER_COMPLETED_AGREEMENTS = "Completed agreements"
L.FOREVER_COMPLETED_COUNTS = "%d completed · %d with you"
L.FOREVER_COMPLETED_PERSONAL = "%d with you"
L.FOREVER_COMPLETED_AGREEMENTS_HELP = "Total reported by this artisan across their characters. “With you” counts agreements completed with your characters. Both participants must confirm completion. Earlier deleted history cannot be recovered."

L.AGREEMENT_TAB = "Agreements"

L.CHANGELOG_ENTRY_FOREVER_2_2_0 = [[### Added
- Arrange private crafting agreements directly from discovery: request a craft, negotiate quantities and commission, accept or decline, and confirm completion together.
- Browse incoming and outgoing agreements in a dedicated tab, with unread badges, notifications, delivery status and retry controls.
- See completed-agreement totals in discovery, with your own completed agreements shown separately.
- Track accepted agreements separately in the objectives tracker and search missing materials with Auctionator.

### Changed
- Agreements use a fixed-size parchment page with quest-style item cards, clear missing-material indicators and a completion stamp.
- Material counts come from the customer and are saved when the agreement is accepted. Reopening an accepted agreement does not request or change those counts; unavailable counts remain unknown.
- Private agreements require both players to use a compatible ArtisanFinder version. They do not automatically craft, trade or transfer gold.]]
