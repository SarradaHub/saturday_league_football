# frozen_string_literal: true

json.id player.id
json.name player.name
json.rounds player.rounds
player_totals = if defined?(@player_stats_totals)
                  @player_stats_totals[player.id]
                end || { goals: 0, assists: 0, own_goals: 0 }

json.total_goals player_totals[:goals]
json.total_assists player_totals[:assists]
json.total_own_goals player_totals[:own_goals]
json.player_stats player.player_stats
json.created_at player.created_at
json.updated_at player.updated_at
