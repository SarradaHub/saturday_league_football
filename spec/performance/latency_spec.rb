require 'rails_helper'

return unless ENV['PERF_SPECS'] == '1'

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/ScatteredLet

RSpec.describe 'Latency thresholds for list and detail endpoints', type: :request do
  let(:current_user) { FactoryBot.create(:user, external_id: '1', email: 'test.user@example.com') }
  let(:list_endpoints) do
    [
      '/api/v1/championships',
      '/api/v1/players',
      '/api/v1/rounds',
      '/api/v1/teams',
      '/api/v1/matches',
      '/api/v1/player_stats',
      "/api/v1/player_stats/match/#{match.id}"
    ]
  end
  let(:detail_endpoints) do
    [
      "/api/v1/championships/#{championship.id}",
      "/api/v1/players/#{player.id}",
      "/api/v1/rounds/#{round.id}",
      "/api/v1/teams/#{teams.first.id}",
      "/api/v1/matches/#{match.id}",
      "/api/v1/player_stats/#{player_stat.id}"
    ]
  end
  let(:championship) { FactoryBot.create(:championship, user: current_user) }
  let(:round) { FactoryBot.create(:round, championship: championship) }
  let(:teams) { FactoryBot.create_list(:team, 2, round: round) }
  let(:match) { FactoryBot.create(:match, round: round, team_1: teams.first, team_2: teams.last) }
  let(:player) { FactoryBot.create(:player) }
  let(:player_stat) { FactoryBot.create(:player_stat, player: player, team: teams.first, match: match) }
  let(:auth_header) { { 'Authorization' => 'Bearer valid_token' } }

  before do
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: current_user.external_id, email: current_user.email }
    })
    allow(Users::SyncFromIdentityService).to receive(:call).and_return(current_user)
    FactoryBot.create(:player_round, player: player, round: round)
    player_stat
  end

  def measure_latency(endpoint)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    get endpoint, headers: auth_header, as: :json
    finish_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(response).to have_http_status(:ok)
    finish_time - start_time
  end



  it 'keeps list endpoints under 500ms' do
    list_endpoints.each do |endpoint|
      elapsed = measure_latency(endpoint)
      expect(elapsed).to be < 0.5
    end
  end

  it 'keeps detail endpoints under 300ms' do
    detail_endpoints.each do |endpoint|
      elapsed = measure_latency(endpoint)
      expect(elapsed).to be < 0.3
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/ScatteredLet
