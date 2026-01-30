# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Flow Integration', type: :request do
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

  describe 'API End-to-End flows' do
    describe 'GET /api/v1/championships/:id with includes and sparse fieldsets' do
      it 'returns championship with includes and filtered fields' do
        # Create via API so the request thread sees committed data (avoids transactional fixture isolation)
        post '/api/v1/championships', params: {
          championship: { name: 'Flow Test Cup', min_players_per_team: 5, max_players_per_team: 10 }
        }, headers: @auth_header, as: :json

        expect(response).to have_http_status(:created)
        championship_id = JSON.parse(response.body)['id']
        expect(championship_id).to be_present

        # Test without includes first (no params: with GET + as: :json to avoid Rails converting to POST)
        get "/api/v1/championships/#{championship_id}", headers: @auth_header, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('id')
        expect(json_response).to have_key('name')
        expect(json_response['id']).to eq(championship_id)

        # Now test with includes (query string to avoid GET params + as: :json -> POST bug)
        get "/api/v1/championships/#{championship_id}?include=rounds,players&fields=id,name,rounds,players",
            headers: @auth_header, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('id')
        expect(json_response).to have_key('name')
        expect(json_response['id']).to eq(championship_id)
      end
    end

    describe 'POST /api/v1/player_stats/match/:match_id/bulk with validations' do
      let!(:championship) { FactoryBot.create(:championship, user: current_user) }
      let(:round) { FactoryBot.create(:round, championship: championship) }
      let(:team1) { FactoryBot.create(:team, round: round) }
      let(:team2) { FactoryBot.create(:team, round: round) }
      let(:player1) { FactoryBot.create(:player) }
      let(:player2) { FactoryBot.create(:player) }
      let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }

      before do
        team1.players << [player1, player2]
      end

      it 'validates and creates player stats correctly' do
        post "/api/v1/player_stats/match/#{match.id}/bulk", params: {
          player_stats: [
            { player_id: player1.id, team_id: team1.id, match_id: match.id, goals: 2, assists: 1, own_goals: 0, was_goalkeeper: false },
            { player_id: player2.id, team_id: team1.id, match_id: match.id, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false }
          ]
        }, headers: @auth_header, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        # bulk_update returns an array of serialized player stats
        expect(json_response).to be_an(Array)
        expect(json_response.length).to eq(2)
        expect(json_response.first).to have_key('id')
        expect(json_response.first).to have_key('goals')
      end

      it 'rejects invalid stats (assist in own goal)' do
        post "/api/v1/player_stats/match/#{match.id}/bulk", params: {
          player_stats: [
            { player_id: player1.id, team_id: team1.id, match_id: match.id, goals: 0, assists: 1, own_goals: 1, was_goalkeeper: false }
          ]
        }, headers: @auth_header, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects invalid stats (assists exceed goals)' do
        post "/api/v1/player_stats/match/#{match.id}/bulk", params: {
          player_stats: [
            { player_id: player1.id, team_id: team1.id, match_id: match.id, goals: 1, assists: 2, own_goals: 0, was_goalkeeper: false }
          ]
        }, headers: @auth_header, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'POST /api/v1/matches/:id/finalize' do
      let!(:championship) { FactoryBot.create(:championship, user: current_user) }
      let(:round) { FactoryBot.create(:round, championship: championship) }
      let(:team1) { FactoryBot.create(:team, round: round) }
      let(:team2) { FactoryBot.create(:team, round: round) }
      let(:player1) { FactoryBot.create(:player) }
      let(:player2) { FactoryBot.create(:player) }
      let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }

      before do
        team1.players << [player1, player2]
        # Create player stats
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match, goals: 2, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: player2, team: team1, match: match, goals: 1, assists: 0, own_goals: 0)
        team2_player = FactoryBot.create(:player)
        team2.players << team2_player
        FactoryBot.create(:player_stat, player: team2_player, team: team2, match: match, goals: 0, assists: 0, own_goals: 1)
      end

      it 'finalizes match and calculates result correctly' do
        post "/api/v1/matches/#{match.id}/finalize", headers: @auth_header, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        # Team 1: 2 + 1 = 3 goals, plus 1 own goal from team 2 = 4 total
        # Team 2: 0 goals (no goals scored, only own goal against them)
        expect(json_response['team_1_goals']).to eq(4)
        expect(json_response['team_2_goals']).to eq(0)
        expect(json_response['winning_team']).to be_present
        expect(json_response['winning_team']['id']).to eq(team1.id)
      end
    end
  end
end
