# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Championship Flow Integration', type: :request do
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

  describe 'Complete championship flow' do
    it 'creates championship, rounds, teams, players and verifies queries and presenters' do
      # Step 1: Create championship
      post '/api/v1/championships', params: {
        championship: {
          name: 'Test Championship',
          description: 'Test Description',
          min_players_per_team: 5,
          max_players_per_team: 10
        }
      }, headers: @auth_header, as: :json

      expect(response).to have_http_status(:created)
      championship_data = JSON.parse(response.body)
      championship_id = championship_data['id']

      # Step 2: Create rounds
      round1 = FactoryBot.create(:round, championship_id: championship_id, name: 'Round 1')
      round2 = FactoryBot.create(:round, championship_id: championship_id, name: 'Round 2')

      # Step 3: Create teams
      team1 = FactoryBot.create(:team, round: round1, name: 'Team A')
      team2 = FactoryBot.create(:team, round: round1, name: 'Team B')
      team3 = FactoryBot.create(:team, round: round2, name: 'Team C')
      team4 = FactoryBot.create(:team, round: round2, name: 'Team D')

      # Step 4: Create players and add to teams and rounds
      player1 = FactoryBot.create(:player, name: 'Player 1')
      player2 = FactoryBot.create(:player, name: 'Player 2')
      player3 = FactoryBot.create(:player, name: 'Player 3')
      player4 = FactoryBot.create(:player, name: 'Player 4')

      team1.players << [player1, player2]
      team2.players << [player3, player4]

      # Add players to rounds so they appear in the championship query
      FactoryBot.create(:player_round, player: player1, round: round1)
      FactoryBot.create(:player_round, player: player2, round: round1)
      FactoryBot.create(:player_round, player: player3, round: round2)
      FactoryBot.create(:player_round, player: player4, round: round2)

      # Step 5: Verify queries return correct data
      # Test Players::CollectionQuery with championship_id filter
      # Note: Players need to be in rounds of the championship to appear in the query
      players_query = Players::CollectionQuery.new(championship_id: championship_id).call
      player_ids = players_query.map(&:id)
      # All players should be in the query since they're in rounds of the championship
      expect(player_ids).to include(player1.id, player2.id, player3.id, player4.id)

      # Test Rounds::CollectionQuery
      rounds_query = Rounds::CollectionQuery.new(relation: Round.where(championship_id: championship_id)).call
      expect(rounds_query.map(&:id)).to include(round1.id, round2.id)

      # Step 6: Verify presenters serialize correctly
      championship_presenter = ChampionshipPresenter.new(Championship.find(championship_id))
      championship_json = championship_presenter.as_json(include_rounds: true, include_players: true)

      expect(championship_json[:id]).to eq(championship_id)
      expect(championship_json[:round_total]).to eq(2)
      expect(championship_json[:total_players]).to eq(4)
      expect(championship_json[:rounds]).to be_an(Array)
      expect(championship_json[:rounds].length).to eq(2)
      expect(championship_json[:players]).to be_an(Array)
      expect(championship_json[:players].length).to eq(4)

      # Step 7: Verify API endpoint returns correct data
      get "/api/v1/championships/#{championship_id}", headers: @auth_header, as: :json

      expect(response).to have_http_status(:ok)
      api_championship = JSON.parse(response.body)

      expect(api_championship['id']).to eq(championship_id)
      expect(api_championship['round_total']).to eq(2)
      expect(api_championship['total_players']).to eq(4)
    end
  end
end
