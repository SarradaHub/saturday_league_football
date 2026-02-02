# frozen_string_literal: true

# FactoryBot is automatically loaded by factory_bot_rails gem in development/test
# No need to manually require or find_definitions

def print_header(title)
  puts "\n\e[33m== #{title} ==\e[0m"
end

def print_item(label, *details)
  puts "✅ \e[32m#{label}\e[0m" + (details.any? ? " - #{details.join(' | ')}" : "")
end

def print_subitem(label, *details)
  puts "  └─ #{label}" + (details.any? ? " - #{details.join(' | ')}" : "")
end

def add_players_to_round(round, players)
  players.each do |player|
    Players::AddToRound.call(player: player, round_id: round.id)
    print_subitem "Player added to round", "Player: #{player.name}", "Round: #{round.name}"
  end
  # Auto-balanceamento via callback de PlayerRound (RoundTeamGenerator)
  round.reload
  teams = round.teams.order(:created_at).to_a
  teams.each do |team|
    print_subitem "Team balanced", "#{team.name} - players: #{team.players.count}"
  end
  teams
end

def finalize_match_with_stats(round:, team1:, team2:, team1_goals:, team2_goals:, team1_own_goals: 0, team2_own_goals: 0, name_suffix: '')
  match = Match.create!(
    round: round,
    team_1: team1,
    team_2: team2,
    name: "#{team1.name} vs #{team2.name}#{name_suffix.present? ? " - #{name_suffix}" : ''}"
  )

  scorer1 = team1.players.first
  scorer2 = team2.players.first

  if team1_goals.positive?
    PlayerStat.create!(
      player: scorer1,
      team: team1,
      match: match,
      goals: team1_goals,
      assists: 0,
      own_goals: 0,
      was_goalkeeper: false
    )
  end

  if team2_goals.positive?
    PlayerStat.create!(
      player: scorer2,
      team: team2,
      match: match,
      goals: team2_goals,
      assists: 0,
      own_goals: 0,
      was_goalkeeper: false
    )
  end

  if team1_own_goals.positive?
    PlayerStat.create!(
      player: scorer1,
      team: team1,
      match: match,
      goals: 0,
      assists: 0,
      own_goals: team1_own_goals,
      was_goalkeeper: false
    )
  end

  if team2_own_goals.positive?
    PlayerStat.create!(
      player: scorer2,
      team: team2,
      match: match,
      goals: 0,
      assists: 0,
      own_goals: team2_own_goals,
      was_goalkeeper: false
    )
  end

  Matches::Finalize.call(match: match)
  match.reload

  print_subitem "Match finalized",
                match.name,
                "Score: #{team1.name} #{team1_goals + team2_own_goals} x #{team2.name} #{team2_goals + team1_own_goals}",
                "Winner: #{match.draw ? 'Draw' : match.winning_team&.name}"

  match
end

def create_goalkeeper_from_other_team(match:, target_team:, source_team:)
  external_player = source_team.players.first
  PlayerStat.create!(
    player: external_player,
    team: target_team,
    match: match,
    goals: 0,
    assists: 0,
    own_goals: 0,
    was_goalkeeper: true
  )
  print_subitem "External goalkeeper",
                "GK: #{external_player.name}",
                "Plays for: #{source_team.name}",
                "Acts as GK for: #{target_team.name}"
end

begin
  print_header "CREATING ADMIN USER"
  admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@example.com')
  admin_password = ENV.fetch('ADMIN_PASSWORD', 'password123')

  admin = if defined?(FactoryBot)
            FactoryBot.create(:user, :admin, email: admin_email, password: admin_password, password_confirmation: admin_password)
          else
            User.find_or_initialize_by(email: admin_email).tap do |u|
              u.password = admin_password
              u.password_confirmation = admin_password
              u.is_admin = true
              u.save!
            end
          end
  print_item "Admin user created", admin_email, "Password: #{admin_password}"

  print_header "CREATING CHAMPIONSHIP"
  players_per_team = 6
  championship = if defined?(FactoryBot)
                   FactoryBot.create(:championship,
                     user: admin,
                     min_players_per_team: players_per_team,
                     max_players_per_team: players_per_team)
                 else
                   Championship.find_or_initialize_by(name: 'Saturday League Demo', user: admin).tap do |c|
                     c.description ||= 'Championship used for seed scenarios'
                     c.min_players_per_team = players_per_team
                     c.max_players_per_team = players_per_team
                     c.save!
                   end
                 end
  print_item "Championship ready", championship.name, "Players per team: #{players_per_team}"

  print_header "CREATING PLAYERS"
  players = if defined?(FactoryBot)
              FactoryBot.create_list(:player, 18)
            else
              18.times.map { |i| Player.create!(name: "Jogador ##{i + 1}") }
            end
  print_item "Players created", "Total: #{players.size}"

  # Rodada 1: Auto-balanceamento e Finalização
  print_header "ROUND 1 - AUTO-BALANCEAMENTO E FINALIZACAO"
  round1 = if defined?(FactoryBot)
             FactoryBot.create(:round, championship: championship)
           else
             Round.create!(name: '1ª Rodada - Auto-balanceamento', championship: championship, round_date: Date.today)
           end
  print_item "Round created", round1.name

  teams1 = add_players_to_round(round1, players)
  teams1.each do |team|
    raise "Team #{team.name} has #{team.players.count} players, expected #{players_per_team}" if team.players.count != players_per_team
  end

  # Criar partidas para demonstrar diferentes resultados
  t1_team1, t1_team2 = teams1.first(2)

  finalize_match_with_stats(
    round: round1,
    team1: t1_team1,
    team2: t1_team2,
    team1_goals: 3,
    team2_goals: 1,
    name_suffix: 'Team1 wins'
  )

  finalize_match_with_stats(
    round: round1,
    team1: t1_team1,
    team2: t1_team2,
    team1_goals: 1,
    team2_goals: 2,
    name_suffix: 'Team2 wins'
  )

  finalize_match_with_stats(
    round: round1,
    team1: t1_team1,
    team2: t1_team2,
    team1_goals: 2,
    team2_goals: 2,
    name_suffix: 'Draw'
  )

  finalize_match_with_stats(
    round: round1,
    team1: t1_team1,
    team2: t1_team2,
    team1_goals: 1,
    team2_goals: 0,
    team2_own_goals: 1,
    name_suffix: 'Own goals impact'
  )

  # Rodada 2: Estatísticas e Sequência Automática
  print_header "ROUND 2 - ESTATISTICAS E SEQUENCIA AUTOMATICA"
  round2 = if defined?(FactoryBot)
             FactoryBot.create(:round, championship: championship)
           else
             Round.create!(name: '2ª Rodada - Estatisticas', championship: championship, round_date: Date.today)
           end
  print_item "Round created", round2.name

  teams2 = add_players_to_round(round2, players)
  t2_team1, t2_team2 = teams2.first(2)

  finalize_match_with_stats(
    round: round2,
    team1: t2_team1,
    team2: t2_team2,
    team1_goals: 2,
    team2_goals: 0,
    name_suffix: 'Stats Match 1'
  )

  finalize_match_with_stats(
    round: round2,
    team1: t2_team1,
    team2: t2_team2,
    team1_goals: 0,
    team2_goals: 1,
    name_suffix: 'Stats Match 2'
  )

  stats = RoundStatistics.call(round_id: round2.id)
  print_subitem "Round statistics summary",
                "Players: #{stats.size}",
                "Top scorer goals: #{stats.values.map { |s| s[:goals] }.max || 0}"

  # Demonstrar NextMatchGenerator
  if teams2.size >= 3
    t2_team3 = teams2[2]
    finalize_match_with_stats(
      round: round2,
      team1: t2_team1,
      team2: t2_team3,
      team1_goals: 2,
      team2_goals: 1,
      name_suffix: 'Sequencia 1'
    )

    suggestion = Rounds::NextMatchGenerator.call(round: round2, create_match: false)
    if suggestion[:needs_winner_selection]
      print_subitem "NextMatch suggestion",
                    "Needs winner selection between: #{suggestion[:candidates].map { |c| c[:name] }.join(' vs ')}",
                    "Next opponent: #{suggestion[:next_opponent][:name]}"
    else
      suggested = suggestion[:suggested_match]
      print_subitem "NextMatch suggestion",
                    "Suggested: #{suggested[:name]}"
    end
  end

  # Rodada 3: Goleiros Externos e Validações
  print_header "ROUND 3 - GOLEIROS EXTERNOS E VALIDACOES"
  round3 = if defined?(FactoryBot)
             FactoryBot.create(:round, championship: championship)
           else
             Round.create!(name: '3ª Rodada - Goleiros e Assistencias', championship: championship, round_date: Date.today)
           end
  print_item "Round created", round3.name

  teams3 = add_players_to_round(round3, players)
  t3_team1, t3_team2, t3_team3 = teams3.first(3)

  match_gk = Match.create!(
    round: round3,
    team_1: t3_team1,
    team_2: t3_team2,
    name: "#{t3_team1.name} vs #{t3_team2.name} - Goleiros externos"
  )

  if t3_team3.present?
    create_goalkeeper_from_other_team(
      match: match_gk,
      target_team: t3_team1,
      source_team: t3_team3
    )
  end

  # Goleiro apenas goleiro (não joga na linha) - criar novo jogador para isso
  keeper_only = if defined?(FactoryBot)
                  FactoryBot.create(:player)
                else
                  Player.create!(name: 'Goleiro Exclusivo')
                end
  PlayerStat.create!(
    player: keeper_only,
    team: t3_team2,
    match: match_gk,
    goals: 0,
    assists: 0,
    own_goals: 0,
    was_goalkeeper: true
  )
  print_subitem "Goalkeeper only",
                "GK: #{keeper_only.name}",
                "Team: #{t3_team2.name}"

  # Validações de assistências
  match_assists = Match.create!(
    round: round3,
    team_1: t3_team1,
    team_2: t3_team2,
    name: "#{t3_team1.name} vs #{t3_team2.name} - Assistencias"
  )

  scorer_valid = t3_team1.players.first
  PlayerStat.create!(
    player: scorer_valid,
    team: t3_team1,
    match: match_assists,
    goals: 2,
    assists: 2,
    own_goals: 0,
    was_goalkeeper: false
  )
  print_subitem "Valid assists",
                "#{scorer_valid.name}",
                "Goals: 2, Assists: 2"

  own_goal_player = t3_team2.players.first
  PlayerStat.create!(
    player: own_goal_player,
    team: t3_team2,
    match: match_assists,
    goals: 0,
    assists: 0,
    own_goals: 1,
    was_goalkeeper: false
  )
  print_subitem "Valid own goal (no assist)",
                "#{own_goal_player.name}",
                "Own goals: 1, Assists: 0"

  # Tentativas inválidas para demonstrar validações (não usam bang)
  invalid1 = PlayerStat.new(
    player: t3_team1.players.second,
    team: t3_team1,
    match: match_assists,
    goals: 0,
    assists: 1,
    own_goals: 0,
    was_goalkeeper: false
  )
  unless invalid1.save
    print_subitem "Invalid assists (no goals)",
                  invalid1.errors.full_messages.join(', ')
  end

  invalid2 = PlayerStat.new(
    player: t3_team2.players.second,
    team: t3_team2,
    match: match_assists,
    goals: 0,
    assists: 1,
    own_goals: 1,
    was_goalkeeper: false
  )
  unless invalid2.save
    print_subitem "Invalid assists on own goals",
                  invalid2.errors.full_messages.join(', ')
  end

  print_header "FINAL CREATION REPORT"
  puts "\n\e[34mTotal Created Records:\e[0m"
  puts "• Users: #{User.count} (#{User.admin.count} admin)"
  puts "• Championships: #{Championship.count}"
  puts "• Rounds: #{Round.count}"
  puts "• Matches: #{Match.count}"
  puts "• Teams: #{Team.count}"
  puts "• Players: #{Player.count}"
  puts "• PlayerTeams: #{PlayerTeam.count}"
  puts "• PlayerRounds: #{PlayerRound.count}"
  puts "• PlayerStats: #{PlayerStat.count}"

  admin = User.admin.first
  if admin
    puts "\n\e[33mAdmin Login Credentials:\e[0m"
    puts "• Email: #{admin.email}"
    puts "• Password: #{ENV.fetch('ADMIN_PASSWORD', 'password123')}"
  end

  puts "\n\e[32m✅ Seed data created successfully!\e[0m"

rescue => e
  puts "\n\e[31m❌ Error: #{e.message}\e[0m"
  puts e.backtrace.first(5).join("\n")
  raise
end
