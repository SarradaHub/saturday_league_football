require 'rails_helper'

RSpec.describe 'API contracts for core resources', type: :request do
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

  def expect_keys(payload, keys)
    keys.each do |key|
      expect(payload).to have_key(key)
    end
  end

  def expect_list_contract(endpoint, required_keys)
    get endpoint, headers: auth_header, as: :json
    expect(response).to have_http_status(:ok)
    json_response = JSON.parse(response.body)

    expect(json_response).to have_key('data')
    expect(json_response['data']).to be_an(Array)
    expect(json_response['data']).not_to be_empty
    expect(json_response).to have_key('meta')
    expect_keys(json_response['meta'], %w[page per_page total total_pages])

    expect_keys(json_response['data'].first, required_keys)
  end

  def expect_show_contract(endpoint, required_keys)
    get endpoint, headers: auth_header, as: :json
    expect(response).to have_http_status(:ok)
    json_response = JSON.parse(response.body)
    expect_keys(json_response, required_keys)
  end

  it 'validates list contracts for core resources' do
    expect_list_contract('/api/v1/championships', %w[id name total_players round_total created_at updated_at])
    expect_list_contract('/api/v1/players', %w[id name total_goals total_assists total_own_goals total_matches created_at updated_at])
    expect_list_contract('/api/v1/rounds', %w[id name round_date championship_id created_at updated_at])
    expect_list_contract('/api/v1/teams', %w[id name round_id created_at updated_at])
    expect_list_contract('/api/v1/matches', %w[id name round_id draw team_1_goals team_2_goals created_at updated_at])
    expect_list_contract('/api/v1/player_stats', %w[id goals assists own_goals was_goalkeeper match_id team_id player_id created_at updated_at])
    expect_list_contract("/api/v1/player_stats/match/#{match.id}", %w[id goals assists own_goals was_goalkeeper match_id team_id player_id created_at updated_at])
  end

  it 'validates detail contracts for core resources' do
    expect_show_contract("/api/v1/championships/#{championship.id}", %w[id name total_players round_total created_at updated_at])
    expect_show_contract("/api/v1/players/#{player.id}", %w[id name total_goals total_assists total_own_goals total_matches created_at updated_at])
    expect_show_contract("/api/v1/rounds/#{round.id}", %w[id name round_date championship_id created_at updated_at])
    expect_show_contract("/api/v1/teams/#{team_1.id}", %w[id name round_id created_at updated_at])
    expect_show_contract("/api/v1/matches/#{match.id}", %w[id name round_id draw team_1_goals team_2_goals created_at updated_at])
    expect_show_contract("/api/v1/player_stats/#{player_stat.id}", %w[id goals assists own_goals was_goalkeeper match_id team_id player_id created_at updated_at])
  end
end
