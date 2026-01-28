# frozen_string_literal: true

namespace :counter_cache do
  desc 'Recalculate all counter cache columns'
  task recalculate: :environment do
    puts 'Recalculating counter caches...'
    
    # Recalculate rounds_count for championships
    puts 'Recalculating rounds_count for championships...'
    Championship.find_each do |championship|
      championship.update_column(:rounds_count, championship.rounds.count)
    end
    puts "Updated #{Championship.count} championships"
    
    # Recalculate players_count for championships (distinct count)
    puts 'Recalculating players_count for championships...'
    Championship.find_each do |championship|
      Championships::UpdatePlayersCount.call(championship: championship)
    end
    puts "Updated #{Championship.count} championships"
    
    # Recalculate matches_count for rounds
    puts 'Recalculating matches_count for rounds...'
    Round.find_each do |round|
      round.update_column(:matches_count, round.matches.count)
    end
    puts "Updated #{Round.count} rounds"
    
    # Recalculate players_count for rounds
    puts 'Recalculating players_count for rounds...'
    Round.find_each do |round|
      round.update_column(:players_count, round.player_rounds.count)
    end
    puts "Updated #{Round.count} rounds"
    
    # Recalculate players_count for teams
    puts 'Recalculating players_count for teams...'
    Team.find_each do |team|
      team.update_column(:players_count, team.player_teams.count)
    end
    puts "Updated #{Team.count} teams"
    
    # Recalculate player_stats_count for players
    puts 'Recalculating player_stats_count for players...'
    Player.find_each do |player|
      player.update_column(:player_stats_count, player.player_stats.count)
    end
    puts "Updated #{Player.count} players"
    
    puts 'Counter cache recalculation completed!'
  end
end
