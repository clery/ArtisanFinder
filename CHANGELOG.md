# Changelog

## 1.0.4 - 2026-05-17

### Added

- Added a configurable trade-chat lead duration with 5, 10, 15, 30, and 60 minute options.
- Added CurseForge changelog metadata so release notes appear on CurseForge file pages.

### Changed

- Updated LibDBIcon packaging to include only the library file instead of the full upstream repository hierarchy.
- Updated release packaging metadata and icon assets for the packaged addon.

### Fixed

- Fixed LibDBIcon packaging so the packaged addon contains the library at the path loaded by the TOC.
- Fixed duplicated trade-chat artisan leads when the same crafter posts the same profession link repeatedly.
- Fixed customer status messages showing plain item names instead of item-link-style names with tooltips.

## 1.0.1 - 2026-05-17

### Added

- Added an integrated Crafting Orders customer panel that shows available artisans for the selected order item.
- Added a Professions panel integration for crafter commission, notes, availability, and default pricing.
- Added a minimap button for availability controls, auto-availability, and quick access to the Professions panel.
- Added automatic background profession scanning with resumable progress.
- Added reagent recommendation tooltips for customer order planning.
- Added support for trade-chat profession links as temporary uncertified artisan leads.
- Added favorites so preferred artisans can stay at the top of customer results.
- Added an Options -> AddOns -> ArtisanFinder settings panel.
- Added localization support for English, French, German, Spanish, Russian, and Chinese.

### Changed

- Customer results show only live addon responders by default, while favorites can remain visible when unavailable.
- Packaging now uses CurseForge externals for library dependencies instead of vendoring them in the repository.
