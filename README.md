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

Hosted for free at: https://poke-vgc-stats.onrender.com

NOTE: Because I am hosting with the free tier (this is a non-profit side project after all), processing can be a little slow as it is limited by server processing power. I could process everything via js and keep it cached in browser, but I honestly might be the only one (outside of my friends) that use this and when we run on local it works without issue so ¯\_(ツ)_/¯ If it turns out there is demand I might look at better hosting options.
