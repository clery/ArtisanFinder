# Retail and Forever regression tests

Run `rtk proxy python3 Tests/run.py` from the addon directory, or use the script's absolute path from another directory.

The runner validates recursive Lua/XML dependencies for all three manifests, checks client module isolation and shared modules, parses tracked/new Lua source and every runtime dependency with Lua 5.1 (excluding ignored local scratch files), and runs every Lua fixture. It also builds both distribution archives with explicit release version 2.2.0 and checks their runtime includes without relying on the source checkout.

The original Retail suites cover customer order-state refresh, preparation/reagent details, quality wire data, recommendation calculations, guild cache, imports, transfers and large profession-open workloads. [retail_startup.lua](retail_startup.lua) verifies Retail order events, notification/preparation startup and lazy order-panel attachment.

Forever fixtures cover startup with order APIs absent, learned-only scanning and itemless enchant output, protocol isolation and commissions, directory/search/row reuse, recipe controls, nameplate setup/rollback and pooled indicator expiry. [flavor_behavior.lua](flavor_behavior.lua) loads the actual shared crafter UI and checks that each flavor retains its own placement, reagent behavior and command/protocol routing.

Live acceptance still requires both game clients. Check profession open/scan, default and recipe commission/note save/discard, advertising, persistence across reload, another player's query/reply and shared profession links. On Retail, check the order panel, preparation and notifications. On Forever, check the standalone directory, advertising controls, minimap modifiers, nameplate settings and combat suppression.

Forever table/identity coverage includes grouped full-name rows, header filters, retained discovery history, item name ambiguity, item link/drag queries, queued lookup cancellation, native surname handling, legacy preference migration, nameplate matching and import identities. [forever_item_query.lua](forever_item_query.lua) exercises the real query/reply functions for an item whose profession is unknown, with Retail wildcard rejection preserved.

Trade Chat diagnosis: `/af debug on`, wait for a profession advertisement, then `/af debug trade`. The copyable log includes escaped raw hyperlinks, channel names, parser decisions, cached counts and directory filter state. `/af debug off` disables logging.

`forever_linkedinn.lua` covers direct Linked Inn H1/Q1/Q2/D1 interoperability, out-of-order chunks, recipe lookup, source filters, link import, malformed input, rate limits, expiry and coinstallation. Optionally pass a local upstream source directory to validate both encoders/decoders against the actual reference implementation: `rtk proxy lua5.1 Tests/forever_linkedinn.lua /path/to/Linked-Inn`.

`forever_pricing.lua` verifies item/default commission precedence, explicit any-commission overrides, announced default rates, unknown Trade/Linked Inn prices and grouped starting prices. Discovery tests also exercise default commission exchange between clients.

`forever_hierarchy.lua` covers artisan/profession/craft expansion, merged recipe sources, deduplication, collapse state, pagination and default-versus-item pricing. The UI fixture verifies that row clicks expand without whispering; discovery tests verify default notes, including chunked long notes and note-only professions.

`shared_flavor_modules.lua` checks shared implementation ownership, client recipe policy, item-data callback composition and initialization of every Forever discovery transport. Manifest checks also enforce that Retail reagent controls never enter the Forever package.

Private agreement two-client checks: [Forever agreements](AGREEMENTS.md).

[locale_coverage.lua](locale_coverage.lua) checks every shared and client-owned string in all ten supported locales, format argument types/order, runtime language selection, and localized current release notes. [forever_translations.lua](forever_translations.lua) retains focused Forever UI coverage.
