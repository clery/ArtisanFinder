# ArtisanFinder release notes

## Retail — [v2.2.0](https://github.com/clery/ArtisanFinder/releases/tag/v2.2.0) (2026-10-19)

### Fixed

- Personal-order notifications now carry recipe and profession identifiers so item and profession names can be resolved in the receiving player's language.
- Oversized legacy notification messages retain their identifiers while dropping display-name fallbacks, or stop safely if they still exceed the message limit.
- Item-data updates refresh only the affected panels and tracked crafts, reducing unnecessary work.

## Forever — [v2.2.0](https://github.com/clery/ArtisanFinder/releases/tag/v2.2.0) (2026-10-19)

### Added

- Arrange private crafting agreements directly from discovery: request a craft, negotiate quantities and commission, accept or decline, and confirm completion together.
- Browse incoming and outgoing agreements in a dedicated tab, with unread badges, notifications, delivery status and retry controls.
- See completed-agreement totals in discovery, with your own completed agreements shown separately.
- Track accepted agreements separately in the objectives tracker and search missing materials with Auctionator.

### Changed

- Agreements use a fixed-size parchment page with quest-style item cards, clear missing-material indicators and a completion stamp.
- Material counts come from the customer and are saved when the agreement is accepted. Reopening an accepted agreement does not request or change those counts; unavailable counts remain unknown.
- Private agreements require both players to use a compatible ArtisanFinder version. They do not automatically craft, trade or transfer gold.
- Discovery prioritizes ArtisanFinder data for artisans also found through other sources, and item-data updates refresh only the affected panels and tracked crafts.

## Release histories

Release histories are maintained separately for each client:

- [Retail changelog](CHANGELOG_RETAIL.md)
- [Forever changelog](CHANGELOG_FOREVER.md)
