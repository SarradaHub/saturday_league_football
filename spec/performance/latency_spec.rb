require 'rails_helper'

return unless ENV['PERF_SPECS'] == '1'

RSpec.describe 'Latency thresholds for list and detail endpoints', type: :request do
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

  def measure_latency(endpoint)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    get endpoint, headers: auth_header, as: :json
    finish_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(response).to have_http_status(:ok)
    finish_time - start_time
  end

  it 'keeps list endpoints under 500ms' do
    endpoints = [
      '/api/v1/championships',
      '/api/v1/players',
      '/api/v1/rounds',
      '/api/v1/teams',
      '/api/v1/matches',
      '/api/v1/player_stats',
      "/api/v1/player_stats/match/#{match.id}"
    ]

    endpoints.each do |endpoint|
      elapsed = measure_latency(endpoint)
      expect(elapsed).to be < 0.5
    end
  end

  it 'keeps detail endpoints under 300ms' do
    endpoints = [
      "/api/v1/championships/#{championship.id}",
      "/api/v1/players/#{player.id}",
      "/api/v1/rounds/#{round.id}",
      "/api/v1/teams/#{team_1.id}",
      "/api/v1/matches/#{match.id}",
      "/api/v1/player_stats/#{player_stat.id}"
    ]

    endpoints.each do |endpoint|
      elapsed = measure_latency(endpoint)
      expect(elapsed).to be < 0.3
    end
  end
end
