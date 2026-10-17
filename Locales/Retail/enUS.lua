local _, AF = ...
local L = AF.Locales.enUS


L.CHANGELOG_ENTRY_2_1_5 = [[### Changed
- ArtisanFinder now supports Retail and WoW Forever in the same download, with features tailored to each version.]]

L.CHANGELOG_ENTRY_2_1_4 = [[### Changed

* Updated the interface version for World of Warcraft patch 12.1.5.]]
L.CHANGELOG_ENTRY_2_1_3 = [[### Changed

* Reduced repeated processing when checking outdated profession scans and displaying scanned professions, improving responsiveness with large artisan profiles.

### Fixed

* Prevented action-bar errors after selecting ArtisanFinder controls in Edit Mode.
* Malformed saved scan entries are now safely skipped when building profession lists and outdated-scan summaries.]]
L.CHANGELOG_ENTRY_2_1_2 = [[### Fixed

* Evoker empowered casts such as Fire Breath are no longer interrupted by ArtisanFinder.
* Customer order polling and list refresh now only run while the customer orders UI is open, defer while you are casting/channeling or restricted, and are no longer queued by customer order refresh events.]]
L.CHANGELOG_ENTRY_2_1_1 = [[### Added

* Profession panel reagent previews can now use an "Unlimited reagents" toggle to simulate quality allocations without owning every reagent.
* Profession panel controls can now default to either maximized or minimized from addon options.

### Fixed

* Reagent skill fact scans now tolerate incomplete baseline reagent data instead of failing.
* Profession scan queue processing now exits safely if scan progress data is missing or malformed.
* Trade-link profession parsing now ignores malformed numeric tokens safely.]]
L.CHANGELOG_ENTRY_2_1_0 = [[### Added

* Artisan import/export provides a way to advertise another account's artisans as well as your main account.
* Prepare order now has an Advanced mode that lets customers choose required reagent qualities and optional reagents before tracking a craft.
* ArtisanFinder can now estimate expected craft quality from the selected reagent setup and suggest reagent combinations that reach the best known result without always defaulting to the highest-quality materials.

### Changed

* Profession scans now save the reagent skill facts needed for reliable customer-side quality simulation, recommendations, and advanced preparation. Older scan records that cannot support the new model are cleared or marked outdated so players know which characters need a fresh scan.
* Clicking a matching customer row can now apply tracked craft materials from the Objective Tracker into the Crafting Order form.

### Fixed

* Opening a profession should no longer significantly cause an FPS drop.
* Guild members who can craft an item now show their real online status instead of always appearing offline.
* Trade chat features now work on Russian game clients.
* Full profession scans now spread their work more evenly, with less freezing and stuttering on large professions.]]
L.CHANGELOG_ENTRY_2_0_5 = [[### Added

* Customer rows now include Prepare order actions for standard crafts and crafts with optional reagents.
* Prepared crafts are tracked in the Objective Tracker with required components, selected optional reagents, needed quantities, owned and missing counts, and quality markers.
* Auction House searches from prepared crafts now use Auctionator temporary multi-searches when Auctionator is enabled.

### Changed

* The "Personal Order" and "Guild Order" buttons have been removed to let a simple click on an artisan row autofill the form on the left.]]
L.CHANGELOG_ENTRY_2_0_3 = [[### Fixed

* Whisper tentative on Patron Order NPC or alt characters on Crafting Order completion.]]
L.CHANGELOG_ENTRY_2_0_2 = [[### Added

* Notifications for customers when a crafting order has been fulfilled.]]
L.CHANGELOG_ENTRY_2_0_1 = [[### Added

* Localization for simplified Chinese, Latin America Spanish, Portuguese, and Brazilian Portuguese.

### Changed

* Small communication optimizations.
* Addon message communication is now compressed.

### Fixed

* Small memory leak for long sessions.]]

L.OPTIONS_SECTION_NOTIFICATIONS = "Notifications"
L.OPTIONS_ORDER_SOUND = "Order notification sound"
L.OPTIONS_ORDER_SOUND_DESC = "Choose the sound played for order notifications."
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "Enable order notification sound"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "Play a sound for personal order and fulfilled customer order notifications."
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "Enable order notification banner"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "Show a center-screen banner for personal order and fulfilled customer order notifications."
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS = "Hide alt order notifications when from yourself"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC = "Hide personal order notifications for your alts when sent by one of your characters."
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS = "Hide alt fulfilled-order notifications when from yourself"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC = "Hide fulfilled customer order notifications when sent by one of your characters."
L.OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN = "Shop panel open"
L.OPTIONS_ORDER_SOUND_STORE_DELIVERY = "Shop delivery toast"
L.OPTIONS_ORDER_SOUND_STORE_OPEN = "Shop window"
L.OPTIONS_ORDER_SOUND_BNET_TOAST = "Battle.net toast"
L.OPTIONS_ORDER_SOUND_PROFESSION_TOAST = "Profession toast"
L.OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME = "Calendar chime"
L.OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER = "Work order start"
L.OPTIONS_ORDER_SOUND_BACKPACK_COIN = "Coin select"
L.OPTIONS_ORDER_SOUND_SOULBIND = "Soulbind activation"
L.OPTIONS_ORDER_SOUND_GM_CHAT_WARNING = "GM chat warning"
L.OPTIONS_ORDER_SOUND_READY_CHECK = "Ready check"
L.OPTIONS_ORDER_SOUND_AUCTION = "Auction house"
L.OPTIONS_ORDER_SOUND_CHANNEL = "Sound channel"
L.OPTIONS_ORDER_SOUND_CHANNEL_DESC = "Choose which game sound channel plays order notifications."
L.OPTIONS_SOUND_CHANNEL_DEFAULT = "Master"
L.OPTIONS_SOUND_CHANNEL_SFX = "Sound effects"
L.OPTIONS_SOUND_CHANNEL_MUSIC = "Music"
L.OPTIONS_SOUND_CHANNEL_AMBIENCE = "Ambience"
L.OPTIONS_SOUND_CHANNEL_DIALOG = "Dialog"
L.OPTIONS_PLAY_ORDER_SOUND = "Play Sound"
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "Play the selected order notification sound."
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "Clear Notifications"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "Clear remembered personal order notifications."

L.TUTORIAL_RESET_DONE = "tutorial reset."
L.TUTORIAL_INTRO = "ArtisanFinder works in two places. Open each of your professions once so it can scan your craft data. Then visit the Crafting Order NPC to see available artisans while creating an order."
L.TUTORIAL_MINIMAP_BUTTON = "Use the minimap button to manage ArtisanFinder quickly.\nLeft-click toggles availability, middle-click toggles automatic availability, right-click opens options, and Shift-click hides the button."
L.TUTORIAL_CUSTOMER_STATUS = "Select an order item in the Crafting Order form. ArtisanFinder then searches for matching artisans."
L.TUTORIAL_CUSTOMER_SEARCH = "Filter, sort, or refresh the results for the selected craft."
L.TUTORIAL_CUSTOMER_ROW = "Rows show commission, quality, availability, guild or trade-chat source, and the artisan's note."
L.TUTORIAL_CUSTOMER_ACTION = "Click a real row to autofill the customer order form.\n\nOpen the row menu to favorite an artisan, whisper them, or open their profession when available."
L.TUTORIAL_PROFESSION_NAME = "Tutorial"

L.CUSTOMER_SIDE_PREVIEW = "Customer Preview"
L.CUSTOMER_SIDE_PREVIEW_EMPTY = "No customer-visible data is saved for this row yet."
L.CUSTOMER_SIDE_PREVIEW_SCANNING = "Scanning this craft. Customer preview will update when scanning finishes."
L.TUTORIAL_CRAFTER_PREVIEW = "Hover the Customer Preview icon to see what customers will see for the selected craft, including item-specific values merged with profession defaults."
