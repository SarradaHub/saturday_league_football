# Domain Refactors – November 2025

## Extracted Presentation Layer
- Added presenters for `Match`, `Championship`, `Player`, `Round`, and `Team` to encapsulate aggregation logic previously living in ActiveRecord models.
- Serializers (`TeamSerializer`, `PlayerSerializer`, `PlayerStatSerializer`, `RoundSerializer`) provide plain hashes to API responses and Jbuilder views.
- Statistics-specific presenters (`MatchStatisticsPresenter`) build scoreboard data outside of the models.

## Query & Service Objects
- Queries now wrap eager-loading and filtering for `Championships`, `Matches`, `Players`, `Rounds`, `Teams`, and `PlayerStats`.
- Services manage command-style workflows (`Players::AddToRound`, `Players::AddToTeam`, `Players::MatchStatistics`, `PlayerStats::BulkUpsert`).

## Controller Simplification
- Controllers lean on query/service/presenter layers for CRUD actions, respond with serialized JSON, and standardize responses (e.g., `head :no_content` after destroys).
- Removed custom data-manipulation methods from ActiveRecord models (`Match`, `Championship`, `Player`, `Team`), delegating to support layers instead.

These shifts align the app with clean architecture principles, reduce model bloat, and prepare for future reuse/testing of domain logic.

