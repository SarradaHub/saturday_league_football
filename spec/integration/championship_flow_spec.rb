# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers

RSpec.describe 'Championship Flow Integration', type: :request, slow: true do
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

  describe 'Complete championship flow' do
    let!(:championship_id) do
      post '/api/v1/championships', params: {
        championship: {
          name: 'Test Championship',
          description: 'Test Description',
          min_players_per_team: 5,
          max_players_per_team: 10
        }
      }, headers: auth_header, as: :json

      json_response['id']
    end

    let!(:round1) { FactoryBot.create(:round, championship_id: championship_id, name: 'Round 1') }
    let!(:round2) { FactoryBot.create(:round, championship_id: championship_id, name: 'Round 2') }
    let(:team1) { FactoryBot.create(:team, round: round1, name: 'Team A') }
    let(:team2) { FactoryBot.create(:team, round: round1, name: 'Team B') }
    let(:team3) { FactoryBot.create(:team, round: round2, name: 'Team C') }
    let(:team4) { FactoryBot.create(:team, round: round2, name: 'Team D') }
    let(:players) { FactoryBot.create_list(:player, 4) }

    before do
      team1.players << players[0..1]
      team2.players << players[2..3]
      FactoryBot.create(:player_round, player: players[0], round: round1)
      FactoryBot.create(:player_round, player: players[1], round: round1)
      FactoryBot.create(:player_round, player: players[2], round: round2)
      FactoryBot.create(:player_round, player: players[3], round: round2)

      # Reload championship to get updated counter cache
      championship = Championship.find(championship_id)
      Championship.reset_counters(championship_id, :rounds)
      Championships::UpdatePlayersCount.call(championship: championship)
      championship.reload
    end

    it 'creates championship via API' do
      expect(response).to have_http_status(:created)
      expect(championship_id).to be_present
    end

    it 'returns players for championship query' do
      players_query = Players::CollectionQuery.new(championship_id: championship_id).call
      player_ids = players_query.map(&:id)
      expect(player_ids).to include(*players.map(&:id))
    end

    it 'returns rounds for championship query' do
      rounds_query = Rounds::CollectionQuery.new(relation: Round.where(championship_id: championship_id)).call
      expect(rounds_query.map(&:id)).to include(round1.id, round2.id)
    end

    it 'serializes championship with presenter' do
      championship_presenter = ChampionshipPresenter.new(Championship.find(championship_id))
      championship_json = championship_presenter.as_json(include_rounds: true, include_players: true)
      expect(championship_json[:id]).to eq(championship_id)
    end

    it 'returns presenter round and player counts' do
      championship_presenter = ChampionshipPresenter.new(Championship.find(championship_id))
      championship_json = championship_presenter.as_json(include_rounds: true, include_players: true)
      expect(championship_json[:round_total]).to eq(2)
      expect(championship_json[:total_players]).to eq(4)
    end

    it 'returns presenter collections' do
      championship_presenter = ChampionshipPresenter.new(Championship.find(championship_id))
      championship_json = championship_presenter.as_json(include_rounds: true, include_players: true)
      expect(championship_json[:rounds]).to be_an(Array)
      expect(championship_json[:players]).to be_an(Array)
    end

    it 'returns presenter collection lengths' do
      championship_presenter = ChampionshipPresenter.new(Championship.find(championship_id))
      championship_json = championship_presenter.as_json(include_rounds: true, include_players: true)
      expect(championship_json[:rounds].length).to eq(2)
      expect(championship_json[:players].length).to eq(4)
    end

    it 'returns championship data from API' do
      get "/api/v1/championships/#{championship_id}", headers: auth_header, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'returns API round and player totals' do
      get "/api/v1/championships/#{championship_id}", headers: auth_header, as: :json
      expect(json_response['round_total']).to eq(2)
      expect(json_response['total_players']).to eq(4)
    end

    it 'returns API championship id' do
      get "/api/v1/championships/#{championship_id}", headers: auth_header, as: :json
      expect(json_response['id']).to eq(championship_id)
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
