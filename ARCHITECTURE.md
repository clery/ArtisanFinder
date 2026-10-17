# ArtisanFinder architecture

ArtisanFinder is one addon with two entry points. Both packages install as `ArtisanFinder` and use `ArtisanFinderDB` in their own client's WTF folder. A flavor is selected before bootstrap, not detected ad hoc by individual UI widgets.

## Loading

`ArtisanFinder_Mainline.toc` selects Retail; `ArtisanFinder_Camelot.toc` and the generic fallback select Forever. Common ordered groups are defined once:

| Include | Responsibility |
| --- | --- |
| `Locales/Shared.xml` | Shared languages, before flavor locale overlays |
| `SharedCore.xml` | Utilities, formatting, profiles and SavedVariables |
| `Features/SharedData.xml` | Customer cache, recommendations, guild and Who data |
| `UI/SharedWidgets.xml` | Minimap, edit-mode integration and debug log |

Other common modules appear in both manifests where their dependencies require them. Flavor adapters are loaded before initialization runs. Never load a Retail module to obtain a helper on Forever; extract that helper to a common module instead.

## Shared behavior and client boundaries

| Common implementation | Client-specific behavior |
| --- | --- |
| `Core`, `Utils`, `Features/Social` | Names, unsupported-activity policy, extra discovery protocols |
| `Features/Crafter/ProfessionRecipes.lua` | Current profession, recipe outputs, skill/quality capabilities and scan signatures |
| `Features/Crafter/Scanner.lua` | Forever learned-recipe jobs; Retail orderable/quality probes |
| `Features/Crafter/UI.lua` | Presentation settings in `Flavors/*.lua`; Forever sidebar placement/art/coin controls and discovery tab |
| `Features/Customer/ProfessionOpening.lua` | `CanReliablyOpenProfession` and `GetProfessionOpenGuildGUID` policies |
| `Features/Customer/PreparationTracker.lua` | `CreatePreparedCraftEntry` material selection for each client |
| Locale lookup, settings helpers, tutorial helpers, changelog renderer | Flavor strings, options, tutorials and changelog data |

Retail crafting orders, order notifications, quality, specialization and reagent allocation belong under `Features/Retail`. Forever's directory, full first-and-last names, profession badges, Linked Inn, CraftBoard and Release Gaming protocols belong under `Features/Forever`. Compatible logic should be extracted; these API differences should not be merged by introducing calls to unsupported systems.

## Extension points

- Common crafter construction calls optional `ConfigureCrafterPanel` once after controls exist. Forever installs coin inputs, sidebar art and the discovery tab there.
- Common crafter refresh calls optional `SyncCrafterPanelInputs` after saved/default values load. Programmatic synchronization does not mark edits dirty.
- Retail supplies `InitializeCrafterReagentControls` for allocation callbacks, quality dialogs and flyouts. Forever never loads that module.
- `crafterUIConfig` in the flavor entry point supplies spacing, minimum height, collapse placement and recipe-learning policy to the common panel.
- Background data changes call common `RequestCustomerResultsRefresh`. Retail refreshes immediately; Forever supplies `QueueCustomerResultsRefresh` to coalesce updates. Direct user actions call `RefreshCustomerResults`.
- Common communications initialization calls optional `InitializeFlavorDiscovery`. Forever explicitly initializes native presence, Linked Inn and third-party discovery there; one coordinator refreshes the transports.
- Common `OnItemDataLoaded` dispatches order-notification and directory callbacks, then coalesces crafter/reagent refreshes. A client should extend this dispatch rather than replacing it.

Shared profession-opening code owns pending tokens, retries and failures. Flavor UIs provide link eligibility and guild GUID resolution, and call that shared code from their buttons.

## Forever discovery

`DiscoverySources.lua` owns discovery source identifiers, translated labels and precedence for grouping, filters and sorting. `GuildDirectory.lua` owns guild API snapshots, player exclusion and online-only observation timestamps. `Directory.lua` collects and groups discovery sources; `Hierarchy.lua` builds profession/craft subrows; `DirectoryUI.lua` owns controls and rendering. Network transports publish data changes through the shared refresh dispatcher.

Each UI rebuild creates a local build context and passes it through aggregation and hierarchy construction. Expensive recipe indexes belong to that context, so they are shared during the rebuild and cannot survive into later updates. Do not store a temporary build context on the global addon table.

Nameplate responsibilities are separate: `Indicators.lua` adapts profiles/settings, `NameplateSetup.lua` owns the explicit friendly-name preference and CVar restoration, `Nameplates.lua` owns anchors and name-text visibility, and `NameplateScaling.lua` owns bounded range checks and temporary scale animations. Scaling updates only active overlays and releases timers/animation handlers when they disappear.

Forever recipe controls currently expose profession advertising only. Featured recipes are disabled: no recipe-row decorations, hover callbacks or feature mutations are installed. Existing saved `featuredRecipes` data and the ribbon asset are retained for a future implementation.

## Validation

Run `python3 Tests/run.py` from any directory. It checks Lua syntax, recursive XML/TOC dependencies, client isolation, regression suites and both installable ZIPs. `shared_flavor_modules.lua` additionally verifies that common public methods resolve to shared source files and that both recipe policies and all Forever discovery initializers still work.

Build artifacts with `python3 Tools/package.py --flavor all`. Both archives include every recursively referenced runtime file and only their own flavor modules/changelog. The native UI still needs smoke testing on each client after structural changes: profession switching, sidebar collapse, reload of commissions, profession links, material tracking, and Retail orders.

## Lua diagnostics

`.luarc.json` is the shared LuaLS configuration for VS Code and command-line checks. It targets WoW's Lua 5.1 environment and uses the installed Ketho WoW API annotations. The additional globals cover load-on-demand UI mixins and legacy APIs used as client compatibility fallbacks.

Vendored `Libs` are loaded as libraries. `Tests` are excluded from the addon workspace because their independent mock globals and replacement functions must not change the inferred runtime API signatures. Run `python3 Tests/run.py` to validate those isolated fixtures.

To check addon diagnostics with the Lua language server, run `lua-language-server --check=. --checklevel=Hint`. No diagnostic rules are disabled for addon source files.
