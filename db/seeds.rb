# db/seeds.rb

def print_header(title)
  puts "\n\e[33m== #{title} ==\e[0m"
end

def print_item(label, *details)
  puts "✅ \e[32m#{label}\e[0m" + (details.any? ? " - #{details.join(' | ')}" : "")
end

def print_subitem(label, *details)
  puts "  └─ #{label}" + (details.any? ? " - #{details.join(' | ')}" : "")
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

  print_header "CREATING TEAMS"
  teams = 9.times.map do |i|
    team = FactoryBot.create(:team)
    print_item "Team #{i+1}", team.name
    team
  end

  print_header "CREATING PLAYERS"
  players = 30.times.map do |i|
    player = FactoryBot.create(:player)
    print_item "Player #{i+1}", player.name
    player
  end

  print_header "ASSIGNING PLAYERS TO TEAMS"
  players.each do |player|
    team = teams.sample
    pt = FactoryBot.create(:player_team, player: player, team: team)
    print_item "PlayerTeam ##{pt.id}", "Player: #{player.name}", "Team: #{team.name}"
  end

  print_header "BUILDING CHAMPIONSHIP STRUCTURE"
  championships.each do |championship|
    print_item "Working on Championship: #{championship.name}"

    rounds = 3.times.map do |i|
      round = FactoryBot.create(:round, name: "#{(i+1).ordinalize} Rodada", championship: championship)
      print_subitem "Round #{i+1}", round.name, round.round_date.to_s
      round
    end

    rounds.each do |round|
      print_subitem "Creating matches for #{round.name}"

      3.times do |i|
        team1, team2 = teams.sample(2)
        match = FactoryBot.create(:match,
                                  round: round,
                                  name: "#{(i+1).ordinalize} Partida",
                                  team_1: team1,
                                  team_2: team2,
                                  winning_team_id: [team1.id, team2.id].sample,
                                  draw: false
        )

        print_subitem "Match #{i+1}",
                      "#{team1.name} vs #{team2.name}",
                      "Winner: #{Team.find(match.winning_team_id).name}"

        # Player Stats
        3.times do |stat_num|
          team = [team1, team2].sample
          player = team.players.sample

          stat = FactoryBot.create(:player_stat,
                                   player: player,
                                   team: team,
                                   match: match,
                                   goals: rand(0..2),
                                   own_goals: 0,
                                   assists: rand(0..2),
                                   was_goalkeeper: [true, false].sample
          )

          print_subitem "PlayerStat ##{stat.id}",
                        "#{player.name} (#{team.name})",
                        "Goals: #{stat.goals}",
                        "Assists: #{stat.assists}",
                        "GK: #{stat.was_goalkeeper}"
        end
      end

      # Player Rounds
      print_subitem "Creating player rounds for #{round.name}"
      3.times do |i|
        pr = FactoryBot.create(:player_round,
                               round: round,
                               player: players.sample
        )
        print_subitem "PlayerRound ##{pr.id}",
                      "Player: #{pr.player.name}",
                      "Round: #{round.name}"
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