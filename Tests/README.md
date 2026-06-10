# Offline Regression Tests

Run from repository root:

```sh
lua Tests/profession_open_regression.lua
lua Tests/recommendation.lua
lua Tests/cache_invalidation.lua
lua Tests/guild_roster_cache.lua
lua Tests/customer_reagent_detail.lua
lua Tests/wire_reagent_facts.lua
```

The profession-open regression harness creates a synthetic multi-character saved-data set without loading or changing live WoW saved variables. It verifies profession-link capture scaling, changed-link propagation, disabled automatic scan behavior, manual force scans, and pending-scan UI lookup scaling.

The recommendation harness verifies customer-side quality breakpoints, optional difficulty, concentration quality caps, lowest-sufficient reagent suggestions, highest-impact tie-breaks, and missing-fact rescan handling.

The cache invalidation harness verifies stale alt/customer cache scan entries are preserved as rescan-needed rows without computed recommendations.

The guild roster cache harness verifies partial roster refreshes, authoritative pruning, and connected-realm member name key preservation.

The customer reagent detail harness verifies chunked reagent detail delivery, compact response fallbacks, and shopping list context adoption for refreshed rows.

The wire reagent facts harness verifies the lean reagent-skill-facts wire format: crafter-side shrinking (skill-neutral slots omitted), customer-side rehydration from the local recipe schematic, compact responses never downgrading cached detailed facts, failed-rehydration retry payloads, and legacy full-facts acceptance.
