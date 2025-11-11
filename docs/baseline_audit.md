# Baseline Audit – November 2025

## Code Structure Inventory
- `app/controllers/api/v1`: 7 REST endpoints, direct ActiveRecord usage, no abstraction layers.
- `app/models`: Domain logic concentrated in models (e.g. `Match` aggregates stats and serialization logic).
- `app/views/api/v1`: Jbuilder templates emit raw ActiveRecord objects (e.g. `match.team_1`), no presenters/serializers.
- `app/jobs`, `app/services`, `app/interactors`, `app/policies`: minimal or missing.
- `lib/`, `app/models/concerns`: empty stubs.

## Metrics & Coverage
- `bundle exec rails stats`: 531 code LOC, 101 test LOC; code:test ratio 1:0.2.
- `bundle exec rspec --format documentation`: fails before running examples due to Postgres auth (`postgres` user). SimpleCov reports 1.67% coverage from partial load.
- No automated performance monitoring; Bullet/Skylight not configured.

## Data Layer Observations
- Missing NOT NULL constraints (`matches.name`, `rounds.name`, etc.).
- Rich associations but no counter caches or query objects; potential N+1 when traversing players/player_stats.

## Accessibility & Frontend
- API-only controllers; PWA manifest/service worker present but no HTML views/layouts besides mailers.
- No accessibility linting or automated tooling.

## Tooling & Debugging
- Rubocop/standard style configs absent.
- No documented debugging aids (e.g., pry-byebug) or performance profiling gems.

## Key Pain Points
1. Tight coupling of controllers/models with serialization and business rules.
2. Sparse test suite blocked by database credentials; coverage extremely low.
3. No shared abstractions (services, presenters, policies), limiting maintainability.
4. Performance optimizations (indexes, caching, N+1 detection) not in place.
5. Accessibility considerations missing for any rendered output.

These findings feed directly into the refactor roadmap steps: establish architecture boundaries, extract domain logic, add performance safeguards, and expand testing/tooling.

