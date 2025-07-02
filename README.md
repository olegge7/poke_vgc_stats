# poke-vgc-stats

This app currently aggregates data from the Smogon chaos stats. Data includes general usage percentages, spread comparisons, stat distributions, and restricted pairings.

Planned implementations: Tera Types, Filtering usages/spreads by nature, partner usage percentages, and more.

# How to run locally

1. Ensure you have Ruby on Rails installed on your machine
2. Navigate to the poke-vgc-stats directory
3. Run 'bundle install' to install dependencies
4. Start the app server with 'rails server'
5. The site should be accessible via localhost:3000

No DB is required. The data from smogon is streamed directly via json and cached in memory.
