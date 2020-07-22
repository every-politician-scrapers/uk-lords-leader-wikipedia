Note: This repo is largely a snapshop record of bring Wikidata
information in line with Wikipedia, rather than code specifically
deisgned to be reused.

The code and queries etc here are unlikely to be updated as my process
evolves. Later repos will likely have progressively different approaches
and more elaborate tooling, as my habit is to try to improve at least
one part of the process each time around.

---------

Step 1: Check the Position Item
===============================

The Wikidata item for the
[Leader of the House of Lords](https://www.wikidata.org/wiki/Q2012061)
contains all the data expected already, although it somewhat bizarrely
believes that everyone in this role was appointed by David Cameron.

Step 2: Tracking page
=====================

PositionHolderHistory already exists; current version is
https://www.wikidata.org/w/index.php?title=Talk:Q2012061&oldid=1112213004
with 36 dated memberships and 2 undated; and 34 warnings.

Step 3: Set up the metadata
===========================

The first step in the repo is always to edit [add_P39.js script](add_P39.js) 
to configure the Item ID and source URL.

Step 4: Get local copy of Wikidata information
==============================================

    wd ee --dry add_P39.js | jq -r '.claims.P39.value' |
      xargs wd sparql office-holders.js | tee wikidata.json

Step 5: Scrape
==============

Comparison/source = [Leader of the House of Lords](https://en.wikipedia.org/wiki/Leader_of_the_House_of_Lords)

    wb ee --dry add_P39.js  | jq -r '.claims.P39.references.P4656' |
      xargs bundle exec ruby scraper.rb | tee wikipedia.csv

Getting it to read the table was fairly simple: the main new addition
this time through was code to handle the (fairly common) partial dates.

The `new-qualifiers` script won't handle these properly yet, but we can
tweak that later.

Step 6: Create missing P39s
===========================

    bundle exec ruby new-P39s.rb wikipedia.csv wikidata.json |
      wd ee --batch --summary "Add missing P39s, from $(wb ee --dry add_P39.js | jq -r '.claims.P39.references.P4656')"

32 new additions as officeholders -> https://tools.wmflabs.org/editgroups/b/wikibase-cli/54dbf48241ad1

Step 7: Add missing qualifiers
==============================

    bundle exec ruby new-qualifiers.rb wikipedia.csv wikidata.json |
      wd aq --batch --summary "Add missing qualifiers, from $(wb ee --dry add_P39.js | jq -r '.claims.P39.references.P4656')"

12 additions made as https://tools.wmflabs.org/editgroups/b/wikibase-cli/c27c613af1c26

There are a few suggested corrections of start/end dates, but I'll wait
until everything has synced before looking at those.

Step 8: Refresh the Tracking Page
=================================

New version at https://www.wikidata.org/w/index.php?title=Talk:Q2012061&oldid=1236535982

Still a lot to tidy up, including resolving who became leader in May
1762 (https://twitter.com/tmtm/status/1286051334148554760), but that
will have to wait a while.
