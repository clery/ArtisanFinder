# Changelog

## 1.0.7 - 2026-05-18

### Added

- Added configurable offline cached artisan fallback rows when customer results are sparse.
- Added options for when offline fallback starts and the maximum number of offline rows shown.
- Added long-lived cached trade-chat leads so older matching profession links can appear as offline fallback results.
- Added a scan completion message showing how many reagent recommendations were actually updated.

### Changed

- Profession scans now use lightweight per-recipe skill probes before running expensive reagent recommendation scans.
- Profession skill, tool, and specialization changes now rescan only recipes whose customer-visible capability changed.
- Cached trade-chat leads now use the same cleanup age as other cached customer fallback data.

### Fixed

- Fixed profession panel reopen events starting unnecessary scans.
- Fixed specialization point staging triggering scans before knowledge changes were applied.
- Removed the noisy chat message while waiting for knowledge changes to apply.

## 1.0.6 - 2026-05-17

### Changed

- Cached reagent recommendation details are now refreshed on tooltip hover when they are older than one hour, while fresh cached details are still shown immediately without extra addon messages.
- Trade-chat artisan leads now persist across reloads and sessions while still expiring according to the configured lead duration.
- Saved data schema was updated to preserve persistent trade-chat leads safely.

## 1.0.5 - 2026-05-17

### Changed

- Reagent recommendation details are now requested when a customer opens a tooltip instead of being sent with every live response.
- Customer row rendering and scan queue bookkeeping were refactored into smaller, clearer helpers.
- Customer item selection queries are lightly debounced to reduce addon-message bursts while browsing orders.
- README media was updated with the latest customer view popup and example animation.

### Fixed

- Added the missing customer row helper module referenced by the addon TOC.

## 1.0.4 - 2026-05-17

### Added

- Added a configurable trade-chat lead duration with 5, 10, 15, 30, and 60 minute options.

### Changed

- Updated LibDBIcon packaging to include only the library file instead of the full upstream repository hierarchy.
- Customer result rows now show when addon-enabled crafters answered or trade-chat crafters were found.

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
