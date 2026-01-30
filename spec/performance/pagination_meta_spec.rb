require 'rails_helper'

RSpec.describe 'Pagination meta on list endpoints', type: :request do
  let(:current_user) { FactoryBot.create(:user, external_id: '1', email: 'test.user@example.com') }
  let!(:championship) { FactoryBot.create(:championship, user: current_user) }
  let!(:round) { FactoryBot.create(:round, championship: championship) }
  let!(:team_1) { FactoryBot.create(:team, round: round) }
  let!(:team_2) { FactoryBot.create(:team, round: round) }
  let!(:match) { FactoryBot.create(:match, round: round, team_1: team_1, team_2: team_2) }
  let!(:player) { FactoryBot.create(:player) }
  let!(:player_round) { FactoryBot.create(:player_round, player: player, round: round) }
  let!(:player_stat) { FactoryBot.create(:player_stat, player: player, team: team_1, match: match) }

  before do
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: current_user.external_id, email: current_user.email }
    })
    allow(Users::SyncFromIdentityService).to receive(:call).and_return(current_user)
  end

  def auth_header
    { 'Authorization' => 'Bearer valid_token' }
  end

  def expect_pagination_meta(response)
    json_response = JSON.parse(response.body)
    expect(json_response).to have_key('meta')
    expect(json_response['meta']).to include('page', 'per_page', 'total', 'total_pages')
  end

  it 'returns pagination meta for all list endpoints' do
    endpoints = [
      '/api/v1/championships',
      '/api/v1/players',
      "/api/v1/players?championship_id=#{championship.id}",
      '/api/v1/rounds',
      '/api/v1/teams',
      "/api/v1/teams?round_id=#{round.id}",
      '/api/v1/matches',
      "/api/v1/matches?round_id=#{round.id}",
      '/api/v1/player_stats',
      "/api/v1/player_stats/match/#{match.id}"
    ]

    endpoints.each do |endpoint|
      get endpoint, headers: auth_header, as: :json
      expect(response).to have_http_status(:ok)
      expect_pagination_meta(response)
    end
  end
end
