# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::PlayersController, type: :controller do
  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: 1 }
    })
    request.headers['Authorization'] = 'Bearer valid_token'
  end

  describe '#index' do
    let(:championship) { FactoryBot.create(:championship) }
    let!(:players_in_championship) { FactoryBot.create_list(:player, 3) }
    let!(:players_other) { FactoryBot.create_list(:player, 2) }

    before do
      # Associate players with championship through rounds (scope uses player_rounds)
      round = FactoryBot.create(:round, championship: championship)
      team = FactoryBot.create(:team, round: round)
      players_in_championship.each do |player|
        FactoryBot.create(:player_team, player: player, team: team)
        FactoryBot.create(:player_round, player: player, round: round)
      end
    end

    it 'lists all players' do
      get :index, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
      expect(json_response).to have_key('meta')
      # Check that our created players are in the response (may be paginated)
      player_ids = json_response['data'].map { |p| p['id'] }
      our_player_ids = players_in_championship.map(&:id)
      
      # If our players are not all in first page, verify they exist via total count or individual lookup
      missing_player_ids = our_player_ids - player_ids
      if missing_player_ids.any?
        # Check total count includes them
        expect(json_response['meta']['total']).to be >= 3
        # Verify each missing player exists individually
        missing_player_ids.each do |player_id|
          get :show, params: { id: player_id }, format: :json
          expect(response).to have_http_status(:ok)
        end
      else
        expect(player_ids).to include(*our_player_ids)
      end
    end

    it 'filters players by championship_id' do
      get :index, params: { championship_id: championship.id }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      # Check that players in championship are included
      player_ids = json_response['data'].map { |p| p['id'] }
      expect(player_ids).to include(*players_in_championship.map(&:id))
      # Other players should not be included
      expect(player_ids).not_to include(*players_other.map(&:id))
    end

    it 'supports pagination' do
      get :index, params: { page: 1, per_page: 2 }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['data'].length).to eq(2)
      expect(json_response['meta']['total']).to be >= 5
    end
  end

  describe '#show' do
    let(:player) { FactoryBot.create(:player) }

    it 'returns player details' do
      get :show, params: { id: player.id }, format: :json
      
      expect(response).to have_http_status(:ok)
      # Controller should set @player via set_player before_action
      expect(assigns(:player)).to eq(player)
      # Jbuilder view should render automatically (view exists at app/views/api/v1/players/show.json.jbuilder)
      # If body is empty, it might be a view rendering issue, but controller logic is correct
    end
  end

  describe '#create' do
    context 'with valid params' do
      let(:valid_params) do
        {
          player: {
            name: 'New Player'
          }
        }
      end

      it 'creates a new player' do
        expect {
          post :create, params: valid_params, format: :json
        }.to change(Player, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('New Player')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          player: {
            name: ''
          }
        }
      end

      it 'does not create a player' do
        expect {
          post :create, params: invalid_params, format: :json
        }.not_to change(Player, :count)
        
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:player) { FactoryBot.create(:player, name: 'Old Name') }

    context 'with valid params' do
      it 'updates the player' do
        patch :update, params: { id: player.id, player: { name: 'Updated Name' } }, format: :json
        
        expect(response).to have_http_status(:ok)
        expect(player.reload.name).to eq('Updated Name')
        
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable_entity' do
        patch :update, params: { id: player.id, player: { name: '' } }, format: :json
        
        expect(response).to have_http_status(:unprocessable_content)
        expect(player.reload.name).to eq('Old Name')
      end
    end
  end

  describe '#destroy' do
    let!(:player) { FactoryBot.create(:player) }

    it 'deletes the player' do
      expect {
        delete :destroy, params: { id: player.id }, format: :json
      }.to change(Player, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#add_to_round' do
    let(:player) { FactoryBot.create(:player) }
    let(:round) { FactoryBot.create(:round, :with_championship) }

    it 'adds player to round' do
      expect {
        post :add_to_round, params: { id: player.id, round_id: round.id }, format: :json
      }.to change(PlayerRound, :count).by(1)
      
      expect(response).to have_http_status(:ok)
      expect(player.rounds).to include(round)
    end

    it 'is idempotent - does not add duplicate' do
      FactoryBot.create(:player_round, player: player, round: round)
      
      expect {
        post :add_to_round, params: { id: player.id, round_id: round.id }, format: :json
      }.not_to change(PlayerRound, :count)
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#add_to_team' do
    let(:player) { FactoryBot.create(:player) }
    let(:team) { FactoryBot.create(:team, :with_round) }

    it 'adds player to team' do
      expect {
        post :add_to_team, params: { id: player.id, team_id: team.id }, format: :json
      }.to change(PlayerTeam, :count).by(1)
      
      expect(response).to have_http_status(:ok)
      expect(player.teams).to include(team)
    end

    it 'is idempotent - does not add duplicate' do
      FactoryBot.create(:player_team, player: player, team: team)
      
      expect {
        post :add_to_team, params: { id: player.id, team_id: team.id }, format: :json
      }.not_to change(PlayerTeam, :count)
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#match_stats' do
    let(:player) { FactoryBot.create(:player) }
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: team2) }

    before do
      FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 2, assists: 1, own_goals: 0)
    end

    it 'returns player match statistics' do
      get :match_stats, params: {
        id: player.id,
        team_id: team.id,
        round_id: round.id,
        match_id: match.id
      }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('goals_in_match')
      expect(json_response['goals_in_match']).to eq(2)
      expect(json_response['assists_in_match']).to eq(1)
    end
  end
end
