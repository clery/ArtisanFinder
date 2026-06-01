# ArtisanFinder

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
