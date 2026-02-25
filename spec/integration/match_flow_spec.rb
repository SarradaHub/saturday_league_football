# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers

# rubocop:disable RSpec/ExampleLength

RSpec.describe 'Match Flow Integration', :slow, type: :request do
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

  describe 'Complete match flow' do
    let!(:championship) { FactoryBot.create(:championship, user: current_user) }
    let!(:round) { FactoryBot.create(:round, championship: championship) }
    let!(:teams) do
      [
        FactoryBot.create(:team, round: round, name: 'Team A'),
        FactoryBot.create(:team, round: round, name: 'Team B')
      ]
    end
    let!(:match_id) do
      post '/api/v1/matches', params: {
        match: {
          name: 'Match 1',
          round_id: round.id,
          team_1_id: teams.first.id,
          team_2_id: teams.last.id
        }
      }, headers: auth_header, as: :json

      json_response['id']
    end
    let(:players) do
      [
        FactoryBot.create(:player, first_name: 'Player', last_name: '1'),
        FactoryBot.create(:player, first_name: 'Player', last_name: '2'),
        FactoryBot.create(:player, first_name: 'Player', last_name: '3'),
        FactoryBot.create(:player, first_name: 'Player', last_name: '4')
      ]
    end

    before do
      # Add players to teams
      teams.first.players << players[0..1]
      teams.last.players << players[2..3]
    end


    def create_stats(match_id)
      post "/api/v1/player_stats/match/#{match_id}/bulk", params: {
        player_stats: [
          { player_id: players[0].id, team_id: teams.first.id, match_id: match_id, goals: 2, assists: 1, own_goals: 0, was_goalkeeper: false },
          { player_id: players[1].id, team_id: teams.first.id, match_id: match_id, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false },
          { player_id: players[2].id, team_id: teams.last.id, match_id: match_id, goals: 1, assists: 0, own_goals: 1, was_goalkeeper: false },
          { player_id: players[3].id, team_id: teams.last.id, match_id: match_id, goals: 0, assists: 1, own_goals: 0, was_goalkeeper: false }
        ]
      }, headers: auth_header, as: :json
    end

    def finalize_match(match_id)
      post "/api/v1/matches/#{match_id}/finalize", headers: auth_header, as: :json
    end

    it 'creates match' do
      expect(response).to have_http_status(:created)
      expect(match_id).to be_present
    end

    it 'creates player stats' do
      create_stats(match_id)
      expect(response).to have_http_status(:ok)
    end

    it 'finalizes match' do
      create_stats(match_id)
      finalize_match(match_id)
      expect(response).to have_http_status(:ok)
    end

    it 'calculates final goals' do
      create_stats(match_id)
      finalize_match(match_id)
      # Team 1: 2 + 1 + 1 (own goal from team 2) = 4
      # Team 2: 1 + 0 = 1
      finalize_response = JSON.parse(response.body)
      expect(finalize_response['team_1_goals']).to eq(4)
      expect(finalize_response['team_2_goals']).to eq(1)
    end

    it 'sets winning team' do
      create_stats(match_id)
      finalize_match(match_id)
      finalize_response = JSON.parse(response.body)
      expect(finalize_response['winning_team']).to be_present
      expect(finalize_response['winning_team']['id']).to eq(teams.first.id)
    end

    it 'returns round statistics' do
      create_stats(match_id)
      finalize_match(match_id)
      players.each { |player| FactoryBot.create(:player_round, player: player, round: round) }
      get "/api/v1/rounds/#{round.id}/statistics", headers: auth_header, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)
    end

    it 'includes player stats in round statistics' do
      create_stats(match_id)
      finalize_match(match_id)
      players.each { |player| FactoryBot.create(:player_round, player: player, round: round) }
      get "/api/v1/rounds/#{round.id}/statistics", headers: auth_header, as: :json
      stats_response = JSON.parse(response.body)
      player1_stats = stats_response[players[0].id.to_s]
      expect(player1_stats).to be_present
      expect(player1_stats['goals']).to eq(2)
    end

    it 'includes assists in round statistics' do
      create_stats(match_id)
      finalize_match(match_id)
      players.each { |player| FactoryBot.create(:player_round, player: player, round: round) }
      get "/api/v1/rounds/#{round.id}/statistics", headers: auth_header, as: :json
      stats_response = JSON.parse(response.body)
      player1_stats = stats_response[players[0].id.to_s]
      expect(player1_stats['assists']).to eq(1)
    end
  end
end

# rubocop:enable RSpec/ExampleLength

# rubocop:enable RSpec/MultipleMemoizedHelpers
