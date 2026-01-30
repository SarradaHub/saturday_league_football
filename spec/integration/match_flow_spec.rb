# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Match Flow Integration', type: :request do
  let(:current_user) { FactoryBot.create(:user, external_id: '1', email: 'test.user@example.com') }

  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: current_user.external_id, email: current_user.email }
    })
    allow(Users::SyncFromIdentityService).to receive(:call).and_return(current_user)
    @auth_header = { 'Authorization' => 'Bearer valid_token' }
  end

  describe 'Complete match flow' do
    let(:championship) { FactoryBot.create(:championship, user: current_user) }
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team1) { FactoryBot.create(:team, round: round, name: 'Team A') }
    let(:team2) { FactoryBot.create(:team, round: round, name: 'Team B') }
    let(:player1) { FactoryBot.create(:player, name: 'Player 1') }
    let(:player2) { FactoryBot.create(:player, name: 'Player 2') }
    let(:player3) { FactoryBot.create(:player, name: 'Player 3') }
    let(:player4) { FactoryBot.create(:player, name: 'Player 4') }

    before do
      # Add players to teams
      team1.players << [player1, player2]
      team2.players << [player3, player4]
    end

    it 'creates match, adds stats, and finalizes correctly' do
      # Step 1: Create match
      post '/api/v1/matches', params: {
        match: {
          name: 'Match 1',
          round_id: round.id,
          team_1_id: team1.id,
          team_2_id: team2.id
        }
      }, headers: @auth_header, as: :json

      expect(response).to have_http_status(:created)
      match_data = JSON.parse(response.body)
      match_id = match_data['id']

      # Step 2: Create player stats
      post "/api/v1/player_stats/match/#{match_id}/bulk", params: {
        player_stats: [
          { player_id: player1.id, team_id: team1.id, match_id: match_id, goals: 2, assists: 1, own_goals: 0, was_goalkeeper: false },
          { player_id: player2.id, team_id: team1.id, match_id: match_id, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false },
          { player_id: player3.id, team_id: team2.id, match_id: match_id, goals: 1, assists: 0, own_goals: 1, was_goalkeeper: false },
          { player_id: player4.id, team_id: team2.id, match_id: match_id, goals: 0, assists: 1, own_goals: 0, was_goalkeeper: false }
        ]
      }, headers: @auth_header, as: :json

      expect(response).to have_http_status(:ok)

      # Step 3: Finalize match
      post "/api/v1/matches/#{match_id}/finalize", headers: @auth_header, as: :json

      expect(response).to have_http_status(:ok)
      finalized_match = JSON.parse(response.body)

      # Verify finalization calculated goals correctly
      # Team 1: 2 + 1 = 3 goals, plus 1 own goal from team 2 = 4 total
      # Team 2: 1 goal, plus 1 own goal = 2 total
      # Actually, own goals from team 2 count for team 1, so:
      # Team 1: 2 + 1 + 1 (own goal from team 2) = 4
      # Team 2: 1 + 0 = 1
      expect(finalized_match['team_1_goals']).to eq(4)
      expect(finalized_match['team_2_goals']).to eq(1)

      # Verify winning team is set
      expect(finalized_match['winning_team']).to be_present
      expect(finalized_match['winning_team']['id']).to eq(team1.id)

      # Step 4: Verify round statistics reflect changes
      # First, add players to the round so they appear in statistics
      FactoryBot.create(:player_round, player: player1, round: round)
      FactoryBot.create(:player_round, player: player2, round: round)
      FactoryBot.create(:player_round, player: player3, round: round)
      FactoryBot.create(:player_round, player: player4, round: round)

      get "/api/v1/rounds/#{round.id}/statistics", headers: @auth_header, as: :json

      expect(response).to have_http_status(:ok)
      round_stats = JSON.parse(response.body)

      # Verify player statistics are aggregated
      # round_stats is a hash where keys are player_ids and values are stat objects
      expect(round_stats).to be_a(Hash)
      # RoundStatistics returns a hash with player_id as key
      player1_stats = round_stats[player1.id.to_s]
      expect(player1_stats).to be_present
      expect(player1_stats['goals']).to eq(2)
      expect(player1_stats['assists']).to eq(1)
    end
  end
end
