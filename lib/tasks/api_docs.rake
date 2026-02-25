namespace :api_docs do
  desc 'Generate docs/api_reference.md from current API schema'
  task generate: :environment do
    resources = [
      {
        name: 'Championships',
        endpoints: ['GET /api/v1/championships', 'GET /api/v1/championships/:id'],
        fields: %w[
          id name description min_players_per_team max_players_per_team
          total_players round_total created_at updated_at
        ],
        includes: %w[rounds players rounds.matches rounds.player_rounds.player]
      },
      {
        name: 'Rounds',
        endpoints: ['GET /api/v1/rounds', 'GET /api/v1/rounds/:id'],
        fields: %w[id name round_date championship_id created_at updated_at matches players teams],
        includes: %w[championship matches teams players matches.team_1 matches.team_2]
      },
      {
        name: 'Teams',
        endpoints: ['GET /api/v1/teams', 'GET /api/v1/teams/:id'],
        fields: %w[id name round_id created_at updated_at matches players],
        includes: %w[round players player_teams matches]
      },
      {
        name: 'Players',
        endpoints: ['GET /api/v1/players', 'GET /api/v1/players/:id'],
        fields: %w[
          id name rounds total_goals total_assists total_own_goals
          total_matches player_stats created_at updated_at
        ],
        includes: %w[rounds teams player_stats]
      },
      {
        name: 'Matches',
        endpoints: ['GET /api/v1/matches', 'GET /api/v1/matches/:id'],
        fields: %w[
          id name round_id team_1 team_2 winning_team draw team_1_players team_2_players
          team_1_goals team_2_goals team_1_goals_scorer team_1_assists team_1_own_goals_scorer
          team_2_goals_scorer team_2_assists team_2_own_goals_scorer statistics created_at updated_at
        ],
        includes: %w[round team_1 team_2 winning_team player_stats team_1.players team_2.players]
      },
      {
        name: 'PlayerStats',
        endpoints: [
          'GET /api/v1/player_stats',
          'GET /api/v1/player_stats/:id',
          'GET /api/v1/player_stats/match/:match_id'
        ],
        fields: %w[id goals own_goals assists was_goalkeeper match_id team_id player_id created_at updated_at],
        includes: %w[player team match match.round player.teams]
      }
    ]

    generated_at = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')
    lines = []
    lines << '# API Reference'
    lines << ''
    lines << 'This document is generated from presenters/serializers and describes the JSON shape exposed by the API.'
    lines << ''
    lines << "Generated at: #{generated_at}"
    lines << ''
    lines << '## Common query params'
    lines << ''
    lines << '- `fields`: comma-separated sparse fieldset. Example: `?fields=id,name`'
    lines << '- `include`: comma-separated includes; nested includes use dot notation. Example: `?include=rounds.players`'
    lines << '- `page`, `per_page`: pagination controls for list endpoints'
    lines << ''
    lines << '## List response meta'
    lines << ''
    lines << 'List endpoints return:'
    lines << ''
    lines << '```json'
    lines << '{ "data": [...], "meta": { "page": 1, "per_page": 20, "total": 0, "total_pages": 0 } }'
    lines << '```'
    lines << ''
    lines << '## Resources'
    lines << ''

    resources.each do |resource|
      lines << "### #{resource[:name]}"
      lines << ''
      lines << '**Endpoints**'
      resource[:endpoints].each { |endpoint| lines << "- #{endpoint}" }
      lines << ''
      lines << '**Fields**'
      resource[:fields].each { |field| lines << "- `#{field}`" }
      lines << ''
      lines << '**Includes (examples)**'
      resource[:includes].each { |include_item| lines << "- `#{include_item}`" }
      lines << ''
    end

    doc_path = Rails.root.join('docs', 'api_reference.md')
    doc_path.dirname.mkpath
    doc_path.write(lines.join("\n"))
  end
end
