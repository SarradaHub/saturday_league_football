require 'rails_helper'

RSpec.describe 'Response size reductions with sparse fieldsets', type: :request do
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

  def response_size_for(endpoint)
    get endpoint, headers: auth_header, as: :json
    expect(response).to have_http_status(:ok)
    response.body.bytesize
  end

  it 'reduces response size by at least 50% with fields param' do
    endpoints = [
      { name: 'championships', base: '/api/v1/championships', fields: 'id,name' },
      { name: 'players', base: '/api/v1/players', fields: 'id,name' },
      { name: 'rounds', base: '/api/v1/rounds', fields: 'id,name' },
      { name: 'teams', base: '/api/v1/teams', fields: 'id,name' },
      { name: 'matches', base: '/api/v1/matches', fields: 'id,name,round_id' },
      { name: 'player_stats', base: '/api/v1/player_stats', fields: 'id,goals' },
      { name: 'player_stats_by_match', base: "/api/v1/player_stats/match/#{match.id}", fields: 'id,goals' }
    ]

    endpoints.each do |endpoint|
      full_size = response_size_for(endpoint[:base])
      sparse_size = response_size_for("#{endpoint[:base]}?fields=#{endpoint[:fields]}")

      expect(full_size).to be > 0
      expect(sparse_size).to be < full_size
      expect(sparse_size).to be <= (full_size * 0.5)
    end
  end
end
