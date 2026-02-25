# Architecture

## Current Architecture Overview

### Layers

The application follows a clean architecture pattern with the following layers:

- **Controllers** (`app/controllers/api`): Thin HTTP adapters inheriting from `Api::BaseController`, focused on orchestration and serialization.
- **Services** (`app/services`): Command-style objects invoked via `.call` for business workflows and side-effect orchestration.
- **Queries** (`app/queries`): Read-model helpers encapsulating complex ActiveRecord queries.
- **Presenters** (`app/presenters`): View-facing decorators to prepare data for serialization.
- **Serializers** (`app/serializers`): Responsible for shaping API payloads independently of ActiveRecord models.
- **Policies** (`app/policies`): Authorization boundaries (stubbed for future expansion).

### Autoloading

`config/application.rb` loads each layer via Zeitwerk to keep naming conventions and autoloading consistent.

## Refactoring History (November 2025)

### Extracted Presentation Layer

- Added presenters for `Match`, `Championship`, `Player`, `Round`, and `Team` to encapsulate aggregation logic previously living in ActiveRecord models.
- Serializers (`TeamSerializer`, `PlayerSerializer`, `PlayerStatSerializer`, `RoundSerializer`) provide plain hashes to API responses and Jbuilder views.
- Statistics-specific presenters (`MatchStatisticsPresenter`) build scoreboard data outside of the models.

### Query & Service Objects

- Queries now wrap eager-loading and filtering for `Championships`, `Matches`, `Players`, `Rounds`, `Teams`, and `PlayerStats`.
- Services manage command-style workflows (`Players::AddToRound`, `Players::AddToTeam`, `Players::MatchStatistics`, `PlayerStats::BulkUpsert`).

### Controller Simplification

- Controllers lean on query/service/presenter layers for CRUD actions, respond with serialized JSON, and standardize responses (e.g., `head :no_content` after destroys).
- Removed custom data-manipulation methods from ActiveRecord models (`Match`, `Championship`, `Player`, `Team`), delegating to support layers instead.

These shifts align the app with clean architecture principles, reduce model bloat, and prepare for future reuse/testing of domain logic.

## Previous State (Before November 2025 Refactors)

### Code Structure

- `app/controllers/api/v1`: 7 REST endpoints, direct ActiveRecord usage, no abstraction layers.
- `app/models`: Domain logic concentrated in models (e.g. `Match` aggregates stats and serialization logic).
- `app/views/api/v1`: Jbuilder templates emit raw ActiveRecord objects (e.g. `match.team_1`), no presenters/serializers.
- `app/jobs`, `app/services`, `app/interactors`, `app/policies`: minimal or missing.
- `lib/`, `app/models/concerns`: empty stubs.

### Metrics & Coverage

- `bundle exec rails stats`: 531 code LOC, 101 test LOC; code:test ratio 1:0.2.
- `bundle exec rspec --format documentation`: fails before running examples due to Postgres auth (`postgres` user). SimpleCov reports 1.67% coverage from partial load.
- No automated performance monitoring; Bullet/Skylight not configured.

### Data Layer

- Missing NOT NULL constraints (`matches.name`, `rounds.name`, etc.).
- Rich associations but no counter caches or query objects; potential N+1 when traversing players/player_stats.

### Key Pain Points (Resolved)

1. ~~Tight coupling of controllers/models with serialization and business rules.~~ → **Resolved**: Controllers now use services, queries, and presenters.
2. ~~Sparse test suite blocked by database credentials; coverage extremely low.~~ → **Improved**: Test infrastructure and coverage goals established (see [Testing Guide](testing.md)).
3. ~~No shared abstractions (services, presenters, policies), limiting maintainability.~~ → **Resolved**: All abstraction layers now in place.
4. ~~Performance optimizations (indexes, caching, N+1 detection) not in place.~~ → **Partially Resolved**: See [Performance & Accessibility](performance_accessibility.md) for current state.
5. ~~Accessibility considerations missing for any rendered output.~~ → **Partially Resolved**: See [Performance & Accessibility](performance_accessibility.md) for current state.

## Next Steps

- Migrate any remaining heavy model/controller logic into dedicated services, queries, and presenters.
- Add policy/authorization rules once requirements are defined.
- Adopt consistent serializer objects and update controllers to render them.
- Continue expanding test coverage to meet 80% baseline (see [Testing Guide](testing.md)).
- Monitor and optimize performance (see [Performance & Accessibility](performance_accessibility.md)).
