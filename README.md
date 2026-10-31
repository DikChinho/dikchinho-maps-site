# DikChinho — Bangladesh-first navigation

DikChinho is being built as a locally informed navigation platform for Bangladesh, starting with Savar.

## Current public MVP

- Place search using Photon and Nominatim, with Bangladesh-focused result filtering.
- Interactive street map, satellite layer, map-tap start/destination selection.
- Valhalla route planning with distinct profiles for car, motorcycle, motor scooter, bicycle and walking.
- Route preferences: balanced, shortest distance, avoid tolls and avoid highways (where supported by the selected profile).
- Turn-by-turn navigation with GPS, voice prompts, route alternatives and rerouting.
- Road issue reports for local testing. **These are saved only in the current browser on the current device. They are not visible to other users.**

## Live site

https://dikchinho.github.io/dikchinho-maps-site/

## Important service status

This is an early prototype, not a production navigation service. Routing currently uses the public Valhalla demo hosted by FOSSGIS. The Valhalla project describes this server as a fair-use demo and asks applications serving end users to identify themselves and contact the project. DikChinho sends an `X-Client-Id` header, but before public-scale use we must coordinate with the host or deploy our own Valhalla service and Bangladesh road graph.

Search, map tiles and satellite imagery also depend on third-party providers. There is no guaranteed service-level availability or live traffic feed.

## Road data and shared reports

The proposed production database schema is in [supabase/schema.sql](supabase/schema.sql). It is intentionally not connected to any existing Supabase project. Create a **separate project for DikChinho** before running it. Do not use the CER Tracker project.

The schema provides:
- Road segment inventory and local attribute overrides
- Localised place names and aliases
- Geospatial road reports
- Authenticated reporting and report confirmations

The browser-local report workflow is a prototype only. Shared reports require the schema, Supabase Auth, a separately configured public client key, row-level security review, abuse controls and a backend integration.

## Development principles

1. Do not scrape Google Maps or copy Google's proprietary map data.
2. Use OpenStreetMap data under its applicable licence and preserve attribution.
3. Verify local road access, vehicle restrictions, road width and surface before using them as routing rules.
4. Never advertise community demo routing as a production SLA or claim live traffic without a real traffic source.
5. Collect GPS-derived observations only with clear user consent and privacy safeguards.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the build phases and system design.
