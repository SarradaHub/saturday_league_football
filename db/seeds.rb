def print_header(title)
  puts "\n\e[33m== #{title} ==\e[0m"
end

def print_item(label, *details)
  puts "✅ \e[32m#{label}\e[0m" + (details.any? ? " - #{details.join(' | ')}" : "")
end

def print_subitem(label, *details)
  puts "  └─ #{label}" + (details.any? ? " - #{details.join(' | ')}" : "")
end

def calculate_goals_for(match, team, opponent)
  return 0 if team.blank?

  team_stats = Matches::PlayerStatsQuery.call(match: match, team: team)
  team_goals = team_stats.sum(&:goals)
  opponent_own_goals = Matches::PlayerStatsQuery.call(match: match, team: opponent).sum(&:own_goals)

  team_goals + opponent_own_goals
end

def create_player_stats_for_team(match, team, is_winning_team: false, is_losing: false)
  players = team.players.to_a
  return [] if players.empty?

  # Ensure exactly 1 goalkeeper per team
  goalkeeper = players.sample
  field_players = players - [goalkeeper]

  stats = []

  # Create stat for goalkeeper (no goals, no assists)
  stats << FactoryBot.create(:player_stat,
    player: goalkeeper,
    team: team,
    match: match,
    goals: 0,
    own_goals: 0,
    assists: 0,
    was_goalkeeper: true
  )

  # Regra: assistência só existe se existir gol; gol pode existir sem assistência; gol contra não tem assistência.
  # Criar sempre primeiros os jogadores com gols, depois com assistências, para a validação por time passar.
  if is_winning_team
    total_goals = rand(1..2)
    total_assists = rand(0..total_goals)
    assign_goals_and_assists_to_field_players(
      match: match,
      team: team,
      field_players: field_players,
      total_goals: total_goals,
      total_assists: total_assists,
      stats: stats
    )
  elsif is_losing
    field_players.each do |player|
      stats << FactoryBot.create(:player_stat,
        player: player,
        team: team,
        match: match,
        goals: 0,
        own_goals: 0,
        assists: 0,
        was_goalkeeper: false
      )
    end
  else
    total_goals = rand(0..1)
    total_assists = total_goals.zero? ? 0 : rand(0..1)
    assign_goals_and_assists_to_field_players(
      match: match,
      team: team,
      field_players: field_players,
      total_goals: total_goals,
      total_assists: total_assists,
      stats: stats
    )
  end

  stats
end

def assign_goals_and_assists_to_field_players(match:, team:, field_players:, total_goals:, total_assists:, stats:)
  # Montar lista (player, goals, assists). Assistência só com gol; ordem: gols primeiro, depois assistências.
  rows = field_players.map { |p| [p, 0, 0] }
  g_remaining = total_goals
  a_remaining = total_assists

  # Distribuir gols
  idx = 0
  while g_remaining.positive? && idx < rows.size
    r = [g_remaining, 1].min
    rows[idx][1] = r
    g_remaining -= r
    idx += 1
  end

  # Distribuir assistências (só entre quem não fez gol, ou quem fez – mas total já <= total_goals)
  pool = rows.each_with_index.to_a
  pool.shuffle!
  idx = 0
  while a_remaining.positive? && idx < pool.size
    _, i = pool[idx]
    rows[i][2] = 1
    a_remaining -= 1
    idx += 1
  end

  # Criar primeiro quem tem gols, depois quem tem só assistências, depois o resto (validação por time)
  created = rows.sort_by { |_, g, a| [-g, -a] }
  created.each do |player, goals, assists|
    stats << FactoryBot.create(:player_stat,
      player: player,
      team: team,
      match: match,
      goals: goals,
      own_goals: 0,
      assists: assists,
      was_goalkeeper: false
    )
  end
end

begin
  # Clear existing data (uncomment if needed)
  # ActiveRecord::Base.connection.tables.each do |t|
  #   ActiveRecord::Base.connection.execute("TRUNCATE #{t} RESTART IDENTITY CASCADE")
  # end

  print_header "CREATING CHAMPIONSHIPS"
  championships = 3.times.map do |i|
    champ = FactoryBot.create(:championship)
    print_item "Championship #{i+1}", champ.name, champ.description
    champ
  end

  print_header "BUILDING CHAMPIONSHIP STRUCTURE"
  championships.each do |championship|
    print_item "Working on Championship: #{championship.name}"

    # Set championship limits to exactly 6 players per team (5 field + 1 goalkeeper)
    players_per_team = 6
    championship.update!(
      min_players_per_team: players_per_team,
      max_players_per_team: players_per_team
    )
    print_subitem "Championship limits set", "Min: #{players_per_team}, Max: #{players_per_team}"

    # Create rounds for this championship
    print_subitem "Creating rounds for #{championship.name}"
    rounds = 3.times.map do |i|
      round = FactoryBot.create(:round, name: "#{(i+1).ordinalize} Rodada", championship: championship)
      print_subitem "Round #{i+1}", round.name, round.round_date.to_s
      round
    end

    # Create teams for each round and associate them
    print_subitem "Creating teams for #{championship.name}"
    rounds.each do |round|
      # Create 3 teams per round
      3.times do |i|
        team = FactoryBot.create(:team, round: round, name: "Time #{round.name} - #{i+1}")
        print_subitem "Team #{team.name} created for #{round.name}"
      end
    end

    # Add players to rounds (this will automatically distribute them to teams via RoundTeamGenerator)
    # Each team needs exactly 6 players (5 field players + 1 goalkeeper)
    rounds.each do |round|
      print_subitem "Adding players to #{round.name}"
      round_teams_count = round.teams.count
      total_players_needed = round_teams_count * players_per_team
      
      # Create players for this round
      players_for_round = total_players_needed.times.map do |i|
        player = FactoryBot.create(:player)
        print_subitem "Player #{i+1}", player.name
        player
      end
      
      # Skip callback temporarily for better performance
      PlayerRound.skip_callback(:commit, :after, :auto_balance_round_teams)
      
      players_for_round.each do |player|
        pr = FactoryBot.create(:player_round, player: player, round: round)
        print_subitem "PlayerRound created", "Player: #{player.name}", "Round: #{round.name}"
      end
      
      # Re-enable callback
      PlayerRound.set_callback(:commit, :after, :auto_balance_round_teams)
      
      # Call RoundTeamGenerator once after all players are added to this round
      # This will distribute players evenly among teams (6 per team)
      RoundTeamGenerator.call(round)
      print_subitem "Teams balanced for #{round.name} (#{players_per_team} players per team)"
      
      # Verify each team has exactly 6 players
      round.teams.each do |team|
        if team.players.count != players_per_team
          raise "Team #{team.name} has #{team.players.count} players, expected #{players_per_team}"
        end
      end
    end

    # Create matches between teams in the same round
    rounds.each do |round|
      print_subitem "Creating matches for #{round.name}"
      round_teams = round.teams.order(:created_at).to_a

      # Create all possible team combinations for matches
      round_teams.combination(2).each do |team1, team2|
        match = FactoryBot.create(:match,
                                  round: round,
                                  name: "#{team1.name} vs #{team2.name}",
                                  team_1: team1,
                                  team_2: team2,
                                  winning_team_id: nil,
                                  draw: nil
        )

        print_subitem "Match #{match.id}",
                      "#{team1.name} vs #{team2.name}"

        # Decide winner before creating stats (to ensure winner has max 2 goals)
        # Randomly decide winner (or draw)
        match_result = [:team1_wins, :team2_wins, :draw].sample
        
        is_draw = match_result == :draw
        winning_team = if is_draw
                         nil
                       elsif match_result == :team1_wins
                         team1
                       else
                         team2
                       end

        # Create PlayerStat for ALL players of team_1
        print_subitem "Creating PlayerStats for #{team1.name} (#{team1.players.count} players)"
        team1_is_winner = winning_team == team1
        # If team1 is losing (not draw and not winner), ensure it has 0 goals
        team1_is_losing = !is_draw && !team1_is_winner
        team1_stats = create_player_stats_for_team(match, team1, is_winning_team: team1_is_winner, is_losing: team1_is_losing)
        team1_stats.each do |stat|
          print_subitem "PlayerStat ##{stat.id}",
                        "#{stat.player.name} (#{team1.name})",
                        "Goals: #{stat.goals}",
                        "Assists: #{stat.assists}",
                        "GK: #{stat.was_goalkeeper}"
        end

        # Create PlayerStat for ALL players of team_2
        print_subitem "Creating PlayerStats for #{team2.name} (#{team2.players.count} players)"
        team2_is_winner = winning_team == team2
        # If team2 is losing (not draw and not winner), ensure it has 0 goals
        team2_is_losing = !is_draw && !team2_is_winner
        team2_stats = create_player_stats_for_team(match, team2, is_winning_team: team2_is_winner, is_losing: team2_is_losing)
        team2_stats.each do |stat|
          print_subitem "PlayerStat ##{stat.id}",
                        "#{stat.player.name} (#{team2.name})",
                        "Goals: #{stat.goals}",
                        "Assists: #{stat.assists}",
                        "GK: #{stat.was_goalkeeper}"
        end

        # Calculate final goals to verify
        team1_goals = calculate_goals_for(match, team1, team2)
        team2_goals = calculate_goals_for(match, team2, team1)
        
        # Verify winner has max 2 goals
        if winning_team
          winner_goals = winning_team == team1 ? team1_goals : team2_goals
          if winner_goals > 2
            raise "Winner #{winning_team.name} has #{winner_goals} goals, but max is 2"
          end
        end

        # Update match with calculated values
        winning_team_id = winning_team&.id
        match.update!(
          winning_team_id: winning_team_id,
          draw: is_draw
        )

        winner_text = if is_draw
                        "Draw"
                      else
                        winning_team.name
                      end

        print_subitem "Match #{match.id} finalized",
                      "Score: #{team1_goals} x #{team2_goals}",
                      "Winner: #{winner_text}",
                      "Winner goals: #{winning_team ? (winning_team == team1 ? team1_goals : team2_goals) : 'N/A'}"
      end
    end
  end

  print_header "FINAL CREATION REPORT"
  puts "\n\e[34mTotal Created Records:\e[0m"
  puts "• Championships: #{Championship.count}"
  puts "• Rounds: #{Round.count}"
  puts "• Matches: #{Match.count}"
  puts "• Teams: #{Team.count}"
  puts "• Players: #{Player.count}"
  puts "• PlayerTeams: #{PlayerTeam.count}"
  puts "• PlayerRounds: #{PlayerRound.count}"
  puts "• PlayerStats: #{PlayerStat.count}"

  puts "\n\e[32m✅ Seed data created successfully!\e[0m"

rescue => e
  puts "\n\e[31m❌ Error: #{e.message}\e[0m"
  puts e.backtrace.first(5).join("\n")
  raise
end
