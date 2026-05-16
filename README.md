# ArtisanFinder

ArtisanFinder helps World of Warcraft players find and manage crafters directly from the Crafting Orders and Professions UI.

The addon is built around a simple idea: customers should be able to see who is available to craft the item they are trying to order, and crafters should be able to present their services without repeatedly advertising in trade chat.

## For Customers

When you open the Crafting Order form and choose an item, ArtisanFinder shows matching artisans who are currently available. The results are meant to help you quickly answer the questions that usually slow down personal orders:

- Who can craft this item right now?
- What commission are they asking for?
- Did they leave any note about materials, quality, concentration, or special conditions?
- Can I whisper them or prepare a personal order without manually copying their name?

Each result can include the crafter's profession, commission, note, and crafting capability information when available. You can search and sort the list when many artisans are available, then use the row action button to whisper the crafter, open their profession link, or fill personal order fields for review.

ArtisanFinder does not place orders for you. It only helps fill or open the right information so you can review everything before submitting an order yourself.

## For Crafters

ArtisanFinder adds lightweight controls to the Professions UI so you can keep your crafting information ready while using the normal Blizzard profession panel.

You can set:

- An item-specific commission and note for a selected craft.
- A default commission and note for the current profession.
- Whether you are currently available to answer customer searches.

Item-specific values are useful when a craft is expensive, concentration-heavy, rare, or otherwise different from your usual pricing. Profession defaults are useful for everyday crafts where you want a standard commission and note.

Availability is session-based, so you can decide when you want to appear in customer searches. The minimap button gives you a quick way to toggle availability without digging through menus.

## Commission Values

Commission fields use a single gold input:

- `0`: unspecified commission.
- `-1`: free commission.
- Any positive number: commission in gold.

An item-specific commission takes priority over a profession default. If an item has no specific commission, the profession default can be used instead.

## Inspiration

ArtisanFinder was inspired by the convenience of Easycraft.io and the in-game Dofus Artisan list, adapted for World of Warcraft's Crafting Orders and Professions UI.
