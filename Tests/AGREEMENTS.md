# Private crafting agreements: in-game checks

Use two Forever clients with the same build. Enable addon errors and confirm existing discovery and Retail crafting orders still work. The automated tests are listed in [the test guide](README.md).

## Customer and artisan

1. Advertise a scanned profession on the artisan. From the other client, expand a known craft in discovery and hover the request icon. Open the editor.
2. Check the linked craft tooltip, online contact, crafting character, craft count, materials owned/required/missing and total commission. For an advertised alt, the contact must remain the online advertiser while the crafting character shows the alt.
3. Change the craft count and confirm the advertised unit commission multiplies into the total. Enter an explicit zero and confirm it remains free; leave all coin fields empty and confirm it remains unspecified. Try invalid counts and excessive prices.
4. Send. The artisan should receive a discreet notification and unread badge without any window opening. Open `/af agreements`; check Incoming and Outgoing lists, item icons/tooltips, times, prices, paging and unread clearing.
5. Counteroffer as artisan, then accept as customer. Change terms again before a stale acceptance reaches the artisan: the stale acceptance must not approve the new offer. New messages and inventory updates must not erase a counteroffer being typed.
6. Declare completion on either client. Both should show Awaiting confirmation. Confirm on the other client; only then should both show Completed.
7. Repeat with decline, customer cancellation, artisan cancellation after acceptance, and both clients acting nearly simultaneously. Terminal agreements must not reopen.

## Discovery and agreement navigation

- Switch between the native Forever side tabs **ArtisanFinder - Discovery** and **ArtisanFinder - Agreements**. They share one window; unfinished fields and Incoming/Outgoing selections remain intact.
- Open the crafting window. Both ArtisanFinder tabs follow the profession tabs, without a second overlapping navigation stack. Switch between them, then return to a profession. The embedded window remains fixed in place and the crafting title returns with the profession page.
- Receive unread agreements with the window closed or while a profession is open. The Agreements tab shows a red count inside its top-right corner, including **9+**, while minimap and standalone counts stay synchronized. Hover and click the full tab icon without the badge blocking it.
- Drag the standalone window near the right screen edge and try a smaller viewport: both tabs and the unread badge remain reachable.

## Materials and integrations

- Track two accepted agreements for the same recipe, with different counts. Each must have its own objective section and multiplied material requirements. Track the same agreement again: replace its section without changing the other agreement or an ordinary tracked craft.
- Test an enchantment without a positive output item ID. Hover its recipe link and inspect materials without item API errors.
- With Auctionator installed, search missing tracked materials, acquire some materials, and verify live owned/missing counts update. Repeat without Auctionator.
- Test a recipe whose schematic/material data is unavailable. Show the unavailable message while allowing the agreement itself.
- Give the customer and artisan different material stocks. Before acceptance, both agreement views must show the customer's counts, including when only the artisan knows the recipe. Accept, then change bags and reopen/reload both clients: saved agreement counts must remain fixed and trigger no further inventory requests. Unavailable counts remain unknown. Objective-tracker shopping counts may still update live.
- Check quest-style reward cards, white item names and red/green missing-material labels beside the names. The material scrollbar hides when all rows fit.
- Verify fixed agreement page height through editing, delivery, acceptance and completion. Confirm completion and check the bottom-right stamp animation; opening an already completed agreement for the first time also animates. Subsequent openings, including after reload, show a static stamp.

## Delivery, restrictions and persistence

- Use an older client without agreement support. Sending must keep an explicitly unsent draft with Whisper available; there must be no public request message.
- Send to an offline or disconnected supported peer. Verify bounded retries, a failed-delivery indication, explicit Retry, and reconciliation when the peer returns. `/reload` during retries must preserve their budget, records and pending actions.
- Receive updates during combat, an instance and any restricted activity. No agreement window or intrusive notification should appear; the unread badge remains available afterward.
- Ignore an incoming sender and try another request from that sender. Open the ignored-senders menu and allow that player again. Delete terminal history and verify delayed duplicate messages do not recreate it.
- Change characters and internal servers where available. Agreement lists remain isolated to the current character; full first and last names remain intact.
- Pending/counteroffer expiry, 48-hour boundaries, caps, duplicate messages, forged senders, stale revisions and future store versions are covered with simulated clocks in [the protocol regression test](forever_agreements.lua); do not alter the real clock or live saved data to test expiry.

No action should craft, trade, pay, move a character, or publish private terms in guild or discovery channels.
