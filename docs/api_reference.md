# API Reference

This document is generated from presenters/serializers and describes the JSON shape exposed by the API.

Generated at: 2026-01-29 00:00:00 UTC

## Common query params

- `fields`: comma-separated sparse fieldset. Example: `?fields=id,name`
- `include`: comma-separated includes; nested includes use dot notation. Example: `?include=rounds.players`
- `page`, `per_page`: pagination controls for list endpoints

## List response meta

List endpoints return:

```json
{ "data": [...], "meta": { "page": 1, "per_page": 20, "total": 0, "total_pages": 0 } }
```

## Resources

### Championships

**Endpoints**
- GET /api/v1/championships
- GET /api/v1/championships/:id

**Fields**
- `id`
- `name`
- `description`
- `min_players_per_team`
- `max_players_per_team`
- `total_players`
- `round_total`
- `created_at`
- `updated_at`

**Includes (examples)**
- `rounds`
- `players`
- `rounds.matches`
- `rounds.player_rounds.player`

### Rounds

**Endpoints**
- GET /api/v1/rounds
- GET /api/v1/rounds/:id

**Fields**
- `id`
- `name`
- `round_date`
- `championship_id`
- `created_at`
- `updated_at`
- `matches`
- `players`
- `teams`

**Includes (examples)**
- `championship`
- `matches`
- `teams`
- `players`
- `matches.team_1`
- `matches.team_2`

### Teams

**Endpoints**
- GET /api/v1/teams
- GET /api/v1/teams/:id

**Fields**
- `id`
- `name`
- `round_id`
- `created_at`
- `updated_at`
- `matches`
- `players`

**Includes (examples)**
- `round`
- `players`
- `player_teams`
- `matches`

### Players

**Endpoints**
- GET /api/v1/players
- GET /api/v1/players/:id

**Fields**
- `id`
- `name`
- `rounds`
- `total_goals`
- `total_assists`
- `total_own_goals`
- `total_matches`
- `player_stats`
- `created_at`
- `updated_at`

**Includes (examples)**
- `rounds`
- `teams`
- `player_stats`

### Matches

**Endpoints**
- GET /api/v1/matches
- GET /api/v1/matches/:id

**Fields**
- `id`
- `name`
- `round_id`
- `team_1`
- `team_2`
- `winning_team`
- `draw`
- `team_1_players`
- `team_2_players`
- `team_1_goals`
- `team_2_goals`
- `team_1_goals_scorer`
- `team_1_assists`
- `team_1_own_goals_scorer`
- `team_2_goals_scorer`
- `team_2_assists`
- `team_2_own_goals_scorer`
- `statistics`
- `created_at`
- `updated_at`

**Includes (examples)**
- `round`
- `team_1`
- `team_2`
- `winning_team`
- `player_stats`
- `team_1.players`
- `team_2.players`

### PlayerStats

**Endpoints**
- GET /api/v1/player_stats
- GET /api/v1/player_stats/:id
- GET /api/v1/player_stats/match/:match_id

**Fields**
- `id`
- `goals`
- `own_goals`
- `assists`
- `was_goalkeeper`
- `match_id`
- `team_id`
- `player_id`
- `created_at`
- `updated_at`

**Includes (examples)**
- `player`
- `team`
- `match`
- `match.round`
- `player.teams`
