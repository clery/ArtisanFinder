[] Think of a way to advertise a multi-character "shop", so people may find you, and potentially a more complete description of your specializations and such.
[] Add guild functionnality so that if a guild member is connected and has the right profession, they show up in the customer view in a way that indicates they are guild members.
[x] Let your own alt-characters show up in the customer view list (with a note that they are yours, and showing up top in the list)
[x] In debug mode, don't show alt-connected people with my current character name. Add new fake names for that.
[x] Investigate why a character may show up with more professions than they have in the options.
[x] Add a slash option "/af clear options" to only clear options
[x] Add a slash option "/af clear scans" to only clear all my character's scans.
[x] Add a slash option "/af clear artisans" to clear all artisans data (except my own characters and alts)
[x] Rename the slash option "/af clear confirm" to "/af clear all"

[x] If the max quality cannot be reached only with components, but with concentration, add a "Concentration" quality in the customer view quality line. If the line gets too large for the frame, add it as a separate line below the current quality line to avoid overflow
[x] Opening someone else's trade link scans it and registers it as my own character. This should never happen.

[x] Fix customer view collapse button which is showing behind the frame. Same fix as for the ArtisanFinder profession panel

[x] Remove chat debug lines which are not relevant for the end-user.
[x] Remove the /af locale slash commands, unless debug mode is enabled. It should not show in chat for regular users.
[x] Add a check icon on the "Fast scan" button to make it clearer whether this is enabled or not. I'm opened to suggestions for more user-friendly UI to make it clearer.
[x] Update the minimap addon tooltip in real-time, whether when clicking it, or while a profession scan is ongoing.

[x] Don't advertise gathering, cooking and fishing professions by default, but allow them to be scanned.

[] Take into account Optional Reagents, such as "Add Embellishment" and "Customize Secondary Stats" which can increase the craft's difficulty. Most customer orders will at least customize secondary stats, and sometimes add an embellishment. Make it as concise and precise as possible in the customer view tooltip and row description, without adding too much row space, or if it would make it really easier to read, increase the width of the ArtisanFinder customer view (but not so much that the "Current Listings" panel would go off screen)

[x] Fix the tooltip not showing when pressing "Profession" in the customer view popup while the profession panel doesn't open (which suggests the user is offline)
[] Could we use the inability to open the profession panel of an artisan as a way to ensure they are offline, without actually opening it and disturbing the customer's flow ?
[x] Fix profession names in customer view rows using the link's name instead of the client's locale profession name