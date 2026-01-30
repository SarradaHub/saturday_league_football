# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/ExampleLength

RSpec.describe 'API Flow Integration', type: :request do
  let(:current_user) { FactoryBot.create(:user, external_id: '1', email: 'test.user@example.com') }
  let(:auth_header) { { 'Authorization' => 'Bearer valid_token' } }
  let(:json_response) { JSON.parse(response.body) }

  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: current_user.external_id, email: current_user.email }
    })
    allow(Users::SyncFromIdentityService).to receive(:call).and_return(current_user)
  end

  describe 'API End-to-End flows' do
    describe 'GET /api/v1/championships/:id with includes and sparse fieldsets' do
      let(:championship_id) do
        # Create via API so the request thread sees committed data (avoids transactional fixture isolation)
        post '/api/v1/championships', params: {
          championship: { name: 'Flow Test Cup', min_players_per_team: 5, max_players_per_team: 10 }
        }, headers: auth_header, as: :json

        json_response['id']
      end

      before do
        # Test without includes first (no params: with GET + as: :json to avoid Rails converting to POST)
        get "/api/v1/championships/#{championship_id}", headers: auth_header, as: :json
      end

      it 'returns created status' do
        expect(response).to have_http_status(:created)
      end

      it 'returns created championship id' do
        expect(championship_id).to be_present
      end

      it 'returns ok for the default show' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns id and name in default show' do
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('name')
        expect(json_response['id']).to eq(championship_id)
      end

      it 'returns id with includes and fields' do
        # Now test with includes (query string to avoid GET params + as: :json -> POST bug)
        get "/api/v1/championships/#{championship_id}?include=rounds,players&fields=id,name,rounds,players",
            headers: auth_header, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('id')
        expect(json_response['id']).to eq(championship_id)
      end

      it 'returns name with includes and fields' do
        get "/api/v1/championships/#{championship_id}?include=rounds,players&fields=id,name,rounds,players",
            headers: auth_header, as: :json
        expect(json_response).to have_key('name')
      end
    end

    describe 'POST /api/v1/player_stats/match/:match_id/bulk with validations' do
      let!(:championship) { FactoryBot.create(:championship, user: current_user) }
      let(:round) { FactoryBot.create(:round, championship: championship) }
      let(:teams) { FactoryBot.create_list(:team, 2, round: round) }
      let(:players) { FactoryBot.create_list(:player, 2) }
      let(:match) { FactoryBot.create(:match, round: round, team_1: teams.first, team_2: teams.last) }

      before do
        teams.first.players << players
      end

      it 'validates and creates player stats correctly' do
        post "/api/v1/player_stats/match/#{match.id}/bulk", params: {
          player_stats: [
            { player_id: players.first.id, team_id: teams.first.id, match_id: match.id, goals: 2, assists: 1, own_goals: 0, was_goalkeeper: false },
            { player_id: players.last.id, team_id: teams.first.id, match_id: match.id, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false }
          ]
        }, headers: auth_header, as: :json

        expect(response).to have_http_status(:ok)
        # bulk_update returns an array of serialized player stats
        expect(json_response).to be_an(Array)
      end

      it 'returns two stats in response' do
        post "/api/v1/player_stats/match/#{match.id}/bulk", params: {
          player_stats: [
            { player_id: players.first.id, team_id: teams.first.id, match_id: match.id, goals: 2, assists: 1, own_goals: 0, was_goalkeeper: false },
            { player_id: players.last.id, team_id: teams.first.id, match_id: match.id, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false }
          ]
        }, headers: auth_header, as: :json
        expect(json_response.length).to eq(2)
      end

      it 'returns stat fields' do
        post "/api/v1/player_stats/match/#{match.id}/bulk", params: {
          player_stats: [
            { player_id: players.first.id, team_id: teams.first.id, match_id: match.id, goals: 2, assists: 1, own_goals: 0, was_goalkeeper: false }
          ]
        }, headers: auth_header, as: :json
        expect(json_response.first).to have_key('id')
        expect(json_response.first).to have_key('goals')
      end

      it 'rejects invalid stats (assist in own goal)' do
        post "/api/v1/player_stats/match/#{match.id}/bulk", params: {
          player_stats: [
            { player_id: players.first.id, team_id: teams.first.id, match_id: match.id, goals: 0, assists: 1, own_goals: 1, was_goalkeeper: false }
          ]
        }, headers: auth_header, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects invalid stats (assists exceed goals)' do
        post "/api/v1/player_stats/match/#{match.id}/bulk", params: {
          player_stats: [
            { player_id: players.first.id, team_id: teams.first.id, match_id: match.id, goals: 1, assists: 2, own_goals: 0, was_goalkeeper: false }
          ]
        }, headers: auth_header, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'POST /api/v1/matches/:id/finalize' do
      let!(:championship) { FactoryBot.create(:championship, user: current_user) }
      let(:round) { FactoryBot.create(:round, championship: championship) }
      let(:teams) { FactoryBot.create_list(:team, 2, round: round) }
      let(:players) { FactoryBot.create_list(:player, 2) }
      let(:match) { FactoryBot.create(:match, round: round, team_1: teams.first, team_2: teams.last) }

      before do
        teams.first.players << players
        # Create player stats
        FactoryBot.create(:player_stat, player: players.first, team: teams.first, match: match, goals: 2, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: players.last, team: teams.first, match: match, goals: 1, assists: 0, own_goals: 0)
        team2_player = FactoryBot.create(:player)
        teams.last.players << team2_player
        FactoryBot.create(:player_stat, player: team2_player, team: teams.last, match: match, goals: 0, assists: 0, own_goals: 1)
post "/api/v1/matches/#{match.id}/finalize", headers: auth_header, as: :json
      end


      it 'finalizes match and returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns calculated goals' do
        # Team 1: 2 + 1 = 3 goals, plus 1 own goal from team 2 = 4 total
        # Team 2: 0 goals (no goals scored, only own goal against them)
        expect(json_response['team_1_goals']).to eq(4)
        expect(json_response['team_2_goals']).to eq(0)
      end

      it 'returns winning team' do
        expect(json_response['winning_team']).to be_present
        expect(json_response['winning_team']['id']).to eq(teams.first.id)
      end
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/ExampleLength
