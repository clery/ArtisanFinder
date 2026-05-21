# Changelog

## 1.2.3 - 2026-05-21

### Added

- Added first-run minimap button guidance explaining availability, auto-availability, profession panel, and hide shortcuts.
- Added preliminary optional reagent difficulty and quality estimate support for customer rows and tooltips when scan data is available.

### Changed

- Reduced profession scan queue overhead for large recipe lists.
- Reused customer row frames with a frame pool and refactored shared UI styling, option dropdown creation, and event registration code.

### Fixed

- Fixed the hidden discovery channel so it waits for Trade and a stable channel list before joining, and rejoins later if it joined too early.
- Fixed suggested reagent names in customer tooltips so they render in the customer's game locale when detailed scan data is available.
- Fixed row refresh indicators so they only appear on non-addon trade leads and survive customer row recycling.

## 1.2.2 - 2026-05-20

### Added

- Added per-row customer refresh buttons for checking whether stale or offline-fallback artisans are online.
- Added loading indicators to artisan rows while a manual online-status refresh is in progress.
- Added in-form Personal Order and Guild Order warnings so review reminders appear in the Crafting Order form instead of chat.

### Fixed

- Crafter commission and note fields now keep in-progress edits while profession scans refresh the panel.
- Fixed offline fallback limits so increasing the option shows more fallback rows instead of fewer.
- Fixed the customer tutorial row quality examples and row highlight sizing.

## 1.2.1 - 2026-05-20

### Added

- Added an account-wide first-run tutorial.
- Added `/af tutorial reset` to restart the tutorial from the beginning.
- Added scan progress percentage in the ArtisanFinder profession panel.

## 1.2.0 - 2026-05-19

### Added

- Added guild crafter discovery for selected customer order recipes, including guild member rows, guild order filling, and guild profession opening when roster data is available.

## 1.1.4 - 2026-05-19

### Changed

- Manual Refresh can now check one-by-one, every five seconds, whether non-addon users are offline or not.

### Fixed

- Fixed the hidden discovery channel changing the player's chat channel ordering.

## 1.1.3 - 2026-05-19

### Added

- Added in-game presence checks for stale trade-chat and cached artisan leads so confirmed offline artisans can be shown as Offline in customer results.

### Changed

- The customer Profession button is now disabled for confirmed offline leads to avoid opening stale profession links during order preparation.
- Invalidated existing local profession scan data so characters rescan with base profession IDs and updated advertising defaults after upgrading.
- Debug customer rows now include sample concentration quality upgrades.

### Fixed

- Fixed own alt-character rows being treated as external offline leads.

## 1.1.2 - 2026-05-19

### Added

- Added collapse/expand controls for the crafter and customer ArtisanFinder panels.
- Added local own-alt customer rows that appear above other artisans for matching scanned crafts.
- Added granular clear commands for options, scanned craft data, cached external artisans, and favorite artisan marks.

### Changed

- Customer-side Profession actions now show an unavailable tooltip when a known profession link cannot be opened.
- Profession scans now avoid capturing data from linked profession windows opened from customer results.

## 1.1.1 - 2026-05-18

### Added

- Added a crafter-side scanning section with an in-panel Fast scan toggle, a Rescan button, and per-profession availability advertising controls.

### Changed

- Fast scan now runs much more aggressively by processing multiple scan jobs per tick.
- Profession equipment upgrades now interrupt an active scan, discard incomplete progress, and restart with a fresh equipment-change scan.
- Profession scans now skip full recommendation recalculation for equipment-change scans when the recipe skill did not improve.
- Crafter panel layout now groups default commission, scanning, and availability listing controls in the ArtisanFinder side frame.

### Fixed

- Fixed customer row favorite icons not vertically aligning with the certified checkmark.
- Fixed overlap between offline/last-seen text in customer rows.
- Fixed active profession equipment changes not forcing already-parsed incomplete scan items back through the new scan pass.

## 1.1.0 - 2026-05-18

### Added

- Added account-level multi-character artisan profiles so an online character can advertise scanned professions from other characters on the same account.
- Added per-character profession advertising checkboxes in Options -> AddOns -> ArtisanFinder.
- Added minimap tooltip breakdowns showing scanned recipe counts per profession for each stored character.
- Added cross-character customer rows that show the actual crafter while whispering the currently online character.
- Added multi-character debug rows for testing alt-crafter behavior locally.

### Changed

- Personal Order filling now targets the actual crafter character while Whisper targets the online contact character.
- Favorites now follow the actual crafter character instead of whichever alt answered the query.
- Reagent detail requests now include crafter identity so cached tooltip recommendations attach to the correct cross-character row.
- The `Online as ...` customer-row indicator now appears as a separate green line.

### Fixed

- Fixed multi-character advertising options appearing in the wrong options section after scanning a new alt.
- Fixed disabled advertising checkboxes not persisting after reload.
- Fixed `/af clear confirm` leaving stale character profession options visible in the current settings session.

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
