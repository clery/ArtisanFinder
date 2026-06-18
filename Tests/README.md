# Offline Regression Tests

Run from repository root:

```sh
lua Tests/profession_open_regression.lua
lua Tests/recommendation.lua
lua Tests/cache_invalidation.lua
lua Tests/imported_alt_merge.lua
lua Tests/guild_roster_cache.lua
lua Tests/customer_reagent_detail.lua
lua Tests/customer_order_state_refresh.lua
lua Tests/wire_reagent_facts.lua
lua Tests/transfer_payload.lua
```

The profession-open regression harness creates a synthetic multi-character saved-data set without loading or changing live WoW saved variables. It verifies profession-link capture scaling, changed-link propagation, disabled automatic scan behavior, manual force scans, and pending-scan UI lookup scaling.

The recommendation harness verifies customer-side quality breakpoints, optional difficulty, concentration quality caps, lowest-sufficient reagent suggestions, highest-impact tie-breaks, and missing-fact rescan handling.

The cache invalidation harness verifies stale alt/customer cache scan entries are preserved as rescan-needed rows without computed recommendations.

The [imported alt merge harness](imported_alt_merge.lua) verifies imported artisan profiles collapse with same-name live/cache rows, preserve online responder contacts, and move cleanly back to customer cache when cleared.

The guild roster cache harness verifies partial roster refreshes, authoritative pruning, and connected-realm member name key preservation.

The customer reagent detail harness verifies chunked reagent detail delivery, compact response fallbacks, and shopping list context adoption for refreshed rows.

The [customer order state refresh harness](customer_order_state_refresh.lua) verifies customer order state polling stays idle on `CRAFTINGORDERS_CAN_REQUEST`, while the customer orders UI is closed, and while the player is casting or channeling.

The wire reagent facts harness verifies the lean reagent-skill-facts wire format: crafter-side shrinking (skill-neutral slots omitted), customer-side rehydration from the local recipe schematic, compact responses never downgrading cached detailed facts, failed-rehydration retry payloads, and legacy full-facts acceptance.

The transfer payload harness verifies artisan export slimming: runtime scan state, localized/cache text, debug fields, repeated profession links, derivable recipe sets, and full reagent-fact skeletons are removed without mutating saved data.
