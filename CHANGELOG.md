# ArtisanFinder

## [v1.2.4](https://github.com/clery/ArtisanFinder/releases/tag/v1.2.4) (2026-05-21)

[Full Changelog](https://github.com/clery/ArtisanFinder/compare/v1.2.3...v1.2.4) | [Previous Releases](https://github.com/clery/ArtisanFinder/releases)

### Added

* Customer searches now broadcast through guild addon messages as well as the hidden ArtisanFinder channel, with guild responses routed back through the guild channel for non-connected realm members.
* Customer searches now also whisper-query online guild members who are already known to match the selected recipe, without contacting offline guild members.
* ArtisanFinder now remembers which online character last answered for a crafter, so future searches can query that character again when looking up the same crafter.

### Fixed

* Customer results now hide addon crafters, favorites, and trade-chat leads unless they are on a connected realm or in your guild.
* Own alts now keep Personal Order priority when they are on a connected realm, and only fall back to Guild Orders when required.
* Addon-enabled crafters now only answer for saved character profiles that are valid connected-realm or guild order targets.
* Cached addon-enabled crafters no longer appear as unavailable while a fresh live search is still pending.
* Opening customer results with many cached artisans no longer performs expensive guild refreshes, repeated connected-realm scans, or filter formatting for every row.
