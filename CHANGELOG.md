# ArtisanFinder

## Unreleased

### Added

* Profession panel reagent previews can now use an Unlimited reagents toggle to simulate quality allocations without owning every reagent.
* Profession panel controls can now default to either maximized or minimized from addon options.

### Fixed

* Imported customer cache entries now use the addon clock when filling missing timestamps.
* Transfer imports now skip artisan records that cannot produce a valid character identity.
* Reagent skill fact scans now tolerate incomplete baseline reagent data instead of failing.
* Profession scan queue processing now exits safely if scan progress data is missing or malformed.
* Customer row action buttons now use consistent compact sizing and safer crafting-order labels.
* Crafting order notifications now request stable sort order and avoid unsafe optional global reads.
* Preparation tracker, minimap, and LibMarkdown demo integrations now guard optional UI globals before use.
* LibMarkdown email autolinks now have a local encoder fallback instead of calling an undefined helper.

## [v2.1.0](https://github.com/clery/ArtisanFinder/releases/tag/v2.1.0) (2026-06-11)
[Full Changelog](https://github.com/clery/ArtisanFinder/compare/v2.0.5...v2.1.0) | [Previous Releases](https://github.com/clery/ArtisanFinder/releases)

### Added

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
* Full profession scans now spread their work more evenly, with less freezing and stuttering on large professions.

## [v2.0.5](https://github.com/clery/ArtisanFinder/releases/tag/v2.0.5) (2026-06-05)

[Full Changelog](https://github.com/clery/ArtisanFinder/compare/v2.0.4...v2.0.5) | [Previous Releases](https://github.com/clery/ArtisanFinder/releases)

### Added

* Customer rows now include Prepare order actions for standard crafts and crafts with optional reagents.
* Prepared crafts are tracked in the ObjectiveTracker with required components, selected optional reagents, needed quantities, owned and missing counts, and quality markers.
* Auction House searches from prepared crafts now use Auctionator temporary multi-searches when Auctionator is enabled.

### Changed

* The "Personal Order" and "Guild Order" buttons have been removed to let a simple click on an artisan row autofill the form on the left.

## [v2.0.3](https://github.com/clery/ArtisanFinder/releases/tag/v2.0.3) (2026-06-02)

[Full Changelog](https://github.com/clery/ArtisanFinder/compare/v2.0.2...v2.0.3) | [Previous Releases](https://github.com/clery/ArtisanFinder/releases)

### Fixed

* Whisper tentative on Patron Order NPC or alt characters on Crafting Order completion

## [v2.0.2](https://github.com/clery/ArtisanFinder/releases/tag/v2.0.2) (2026-06-02)

[Full Changelog](https://github.com/clery/ArtisanFinder/compare/v2.0.1...v2.0.2) | [Previous Releases](https://github.com/clery/ArtisanFinder/releases)

### Added

* Notifications for customers when a crafting order has been fulfilled.

## [v2.0.1](https://github.com/clery/ArtisanFinder/releases/tag/v2.0.1) (2026-06-02)

[Full Changelog](https://github.com/clery/ArtisanFinder/compare/v2.0.0...v2.0.1) | [Previous Releases](https://github.com/clery/ArtisanFinder/releases)

### Added

* Localization for simplified Chinese, latin america spanish, portuguese and brazilian portuguese.

### Changed

* Small communication optimizations.
* Addon message communication is now compressed.

### Fixed

* Small memory leak for long sessions.

## [v2.0.0](https://github.com/clery/ArtisanFinder/releases/tag/v2.0.0) (2026-06-01)

[Full Changelog](https://github.com/clery/ArtisanFinder/compare/v1.2.6b...v2.0.0) | [Previous Releases](https://github.com/clery/ArtisanFinder/releases)

### Added

* Cross-character personal order notification system.
* Availability can now be cycled between unavailable, current character only, and account-wide.
* The Professions UI now has a customer preview tooltip.
* The minimap button now shows availability color, outdated scan warnings, an Alt-left-click profession advertising menu, and Shift-right-click notification clearing.
* Automatic availability now has per-activity disable options for dungeons, raids, PvP, arenas, and delves.
* A movable ArtisanFinder button mode is available as an alternative to the minimap-ring button.
* Personal order notification toasts can be positioned, scaled, and stacked from Blizzard Edit Mode.
* Personal order notification sound and sound channel can now be chosen in Options, with a play-test button.
* The customer view now has an option to include your current character in results while you are available.

### Changed

* Addon options were reordered to put the most common controls first.
* The collapsed profession-panel reopen button now sits on the right side of the crafting details panel.
* Customer result quality text is more compact and no longer includes the base-quality line.
* Recommended and optional reagent wording is clearer in customer rows and tooltips.

### Fixed

* Save buttons now stay usable while profession scans are running.
* Outdated scan data is now called out more clearly, including in minimap tooltips.
* Collapsing the profession ArtisanFinder panel now leaves only a small reopen button.
