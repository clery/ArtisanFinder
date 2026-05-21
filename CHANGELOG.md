# ArtisanFinder

## [v1.2.4](https://github.com/clery/ArtisanFinder/releases/tag/v1.2.4) (2026-05-21)

[Full Changelog](https://github.com/clery/ArtisanFinder/compare/v1.2.3...v1.2.4) | [Previous Releases](https://github.com/clery/ArtisanFinder/releases)

### Added

* Customer searches now broadcast through guild addon messages as well as the hidden ArtisanFinder channel, so guild members can answer without relying only on the custom channel.

### Fixed

* Customer results now hide addon crafters, favorites, and trade-chat leads unless they are on a connected realm or in your guild.
* Own alts now keep Personal Order priority when they are on a connected realm, and only fall back to Guild Orders when required.
* Opening customer results with many cached artisans no longer performs expensive guild refreshes, repeated connected-realm scans, or filter formatting for every row.
