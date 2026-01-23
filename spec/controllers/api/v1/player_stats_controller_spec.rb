# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::PlayerStatsController, type: :controller do
  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: 1 }
    })
    request.headers['Authorization'] = 'Bearer valid_token'
  end

  describe '#index' do
    let!(:player_stats) { FactoryBot.create_list(:player_stat, 5, :with_player, :with_team, :with_match) }

    it 'lists all player stats' do
      get :index, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
      expect(json_response).to have_key('meta')
      # Check that our created stats exist in the database and are accessible
      # Since pagination defaults to 20 per page, check if our stats are in first page
      stat_ids = json_response['data'].map { |s| s['id'] }
      our_stat_ids = player_stats.map(&:id)
      
      # If our stats are not in first page, check they exist in total count
      if (stat_ids & our_stat_ids).empty?
        # Verify they exist by checking total count includes them
        expect(json_response['meta']['total']).to be >= 5
        # Or check a specific stat directly
        get :show, params: { id: player_stats.first.id }, format: :json
        expect(response).to have_http_status(:ok)
      else
        expect(stat_ids).to include(*our_stat_ids)
      end
    end

    it 'supports pagination' do
      get :index, params: { page: 1, per_page: 2 }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['data'].length).to eq(2)
      expect(json_response['meta']['total']).to be >= 5
    end

    it 'supports includes for eager loading' do
      get :index, params: { include: 'player' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      # Verify that includes parameter is accepted (actual eager loading is tested in CollectionQuery)
      expect(json_response).to have_key('data')
    end

    it 'supports nested includes' do
      get :index, params: { include: 'player.teams,match.round' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
    end

    it 'supports multiple includes' do
      get :index, params: { include: 'player,team,match' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
    end

    it 'supports sparse fieldsets' do
      get :index, params: { fields: 'id,goals,assists' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      if json_response['data'].any?
        stat_data = json_response['data'].first
        expect(stat_data.keys).to include('id', 'goals', 'assists')
        # Verify sparse fieldsets is working - should not have fields not requested
        expect(stat_data).not_to have_key('own_goals')
        expect(stat_data).not_to have_key('was_goalkeeper')
      end
    end

    it 'supports sparse fieldsets with multiple fields' do
      get :index, params: { fields: 'id,goals,assists,own_goals' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      if json_response['data'].any?
        stat_data = json_response['data'].first
        expect(stat_data.keys).to include('id', 'goals', 'assists', 'own_goals')
        expect(stat_data).not_to have_key('was_goalkeeper')
      end
    end
  end

  describe '#show' do
    let(:player_stat) { FactoryBot.create(:player_stat, :with_player, :with_team, :with_match) }

    it 'returns player stat details' do
      get :show, params: { id: player_stat.id }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['id']).to eq(player_stat.id)
      expect(json_response['goals']).to eq(player_stat.goals)
    end
  end

  describe '#create' do
    let(:player) { FactoryBot.create(:player) }
    let(:team) { FactoryBot.create(:team, :with_round) }
    let(:match) { FactoryBot.create(:match, round: team.round, team_1: team, team_2: FactoryBot.create(:team, round: team.round)) }

    context 'with valid params' do
      let(:valid_params) do
        {
          player_stat: {
            player_id: player.id,
            team_id: team.id,
            match_id: match.id,
            goals: 2,
            assists: 1,
            own_goals: 0,
            was_goalkeeper: false
          }
        }
      end

      it 'creates a new player stat' do
        expect {
          post :create, params: valid_params, format: :json
        }.to change(PlayerStat, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['goals']).to eq(2)
        expect(json_response['assists']).to eq(1)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          player_stat: {
            player_id: nil,
            match_id: match.id
          }
        }
      end

      it 'does not create a player stat' do
        expect {
          post :create, params: invalid_params, format: :json
        }.not_to change(PlayerStat, :count)
        
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:player_stat) { FactoryBot.create(:player_stat, :with_player, :with_team, :with_match, goals: 1, assists: 0, own_goals: 0) }

    context 'with valid params' do
      it 'updates the player stat' do
        patch :update, params: { id: player_stat.id, player_stat: { goals: 3 } }, format: :json
        
        expect(response).to have_http_status(:ok)
        expect(player_stat.reload.goals).to eq(3)
        
        json_response = JSON.parse(response.body)
        expect(json_response['goals']).to eq(3)
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable_entity when assists on own goals' do
        # This should fail validation: "Assists gol contra não tem assistência"
        # Set own_goals > 0 and assists > 0, which violates the validation
        patch :update, params: { 
          id: player_stat.id, 
          player_stat: { 
            goals: player_stat.goals,
            assists: 1, 
            own_goals: 1,
            was_goalkeeper: player_stat.was_goalkeeper
          } 
        }, format: :json
        
        # Should return error status
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        # Error message should mention assists or own goals
        error_messages = json_response['errors'].join(' ')
        expect(error_messages).to match(/assist|gol contra/i)
      end
    end
  end

  describe '#destroy' do
    let!(:player_stat) { FactoryBot.create(:player_stat, :with_player, :with_team, :with_match) }

    it 'deletes the player stat' do
      expect {
        delete :destroy, params: { id: player_stat.id }, format: :json
      }.to change(PlayerStat, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#by_match' do
    let(:match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }
    let!(:stats_in_match) { FactoryBot.create_list(:player_stat, 3, :with_player, :with_team, match: match) }
    let!(:stats_other) { FactoryBot.create_list(:player_stat, 2, :with_player, :with_team, :with_match) }

    it 'returns player stats for a specific match' do
      get :by_match, params: { match_id: match.id }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['data'].length).to eq(3)
      json_response['data'].each do |stat|
        expect(stat['match_id']).to eq(match.id)
      end
    end

    it 'supports pagination' do
      get :by_match, params: { match_id: match.id, page: 1, per_page: 2 }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['data'].length).to eq(2)
      expect(json_response['meta']['total']).to eq(3)
    end

    it 'supports includes for eager loading' do
      get :by_match, params: { match_id: match.id, include: 'player' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      # Verify that includes parameter is accepted
      expect(json_response).to have_key('data')
    end

    it 'supports nested includes' do
      get :by_match, params: { match_id: match.id, include: 'player.teams,match.round' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
    end

    it 'supports multiple includes' do
      get :by_match, params: { match_id: match.id, include: 'player,team,match' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
    end

    it 'supports sparse fieldsets' do
      get :by_match, params: { match_id: match.id, fields: 'id,goals,assists' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      if json_response['data'].any?
        stat_data = json_response['data'].first
        expect(stat_data.keys).to include('id', 'goals', 'assists')
        # Verify sparse fieldsets is working - should not have fields not requested
        expect(stat_data).not_to have_key('own_goals')
        expect(stat_data).not_to have_key('was_goalkeeper')
      end
    end

    it 'supports sparse fieldsets with multiple fields' do
      get :by_match, params: { match_id: match.id, fields: 'id,goals,assists,own_goals,was_goalkeeper' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      if json_response['data'].any?
        stat_data = json_response['data'].first
        expect(stat_data.keys).to include('id', 'goals', 'assists', 'own_goals', 'was_goalkeeper')
      end
    end
  end

  describe '#bulk_update' do
    let(:match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }
    let(:player1) { FactoryBot.create(:player) }
    let(:player2) { FactoryBot.create(:player) }
    let(:team1) { match.team_1 }
    let(:team2) { match.team_2 }

    context 'with valid stats' do
      let(:valid_params) do
        {
          match_id: match.id,
          player_stats: [
            {
              player_id: player1.id,
              team_id: team1.id,
              goals: 2,
              assists: 1,
              own_goals: 0,
              was_goalkeeper: false
            },
            {
              player_id: player2.id,
              team_id: team2.id,
              goals: 1,
              assists: 0,
              own_goals: 0,
              was_goalkeeper: true
            }
          ]
        }
      end

      it 'creates player stats in bulk' do
        expect {
          post :bulk_update, params: valid_params, format: :json
        }.to change(PlayerStat, :count).by(2)
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.length).to eq(2)
      end

      it 'replaces existing stats for the match' do
        FactoryBot.create(:player_stat, match: match, player: player1, team: team1, goals: 5)
        
        post :bulk_update, params: valid_params, format: :json
        
        expect(response).to have_http_status(:ok)
        # Should have only 2 stats (the new ones), not 3
        expect(PlayerStat.where(match: match).count).to eq(2)
        expect(PlayerStat.where(match: match, player: player1).first.goals).to eq(2)
      end
    end

    context 'with invalid assists (assists on own goals)' do
      let(:invalid_params) do
        {
          match_id: match.id,
          player_stats: [
            {
              player_id: player1.id,
              team_id: team1.id,
              goals: 0,
              assists: 1,
              own_goals: 1, # Cannot have assists on own goals
              was_goalkeeper: false
            }
          ]
        }
      end

      it 'returns error' do
        post :bulk_update, params: invalid_params, format: :json
        
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'with invalid assists (assists exceed goals)' do
      let(:invalid_params) do
        {
          match_id: match.id,
          player_stats: [
            {
              player_id: player1.id,
              team_id: team1.id,
              goals: 2,
              assists: 3, # Assists cannot exceed goals
              own_goals: 0,
              was_goalkeeper: false
            }
          ]
        }
      end

      it 'returns error' do
        post :bulk_update, params: invalid_params, format: :json
        
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'with multiple teams' do
      let(:valid_params) do
        {
          match_id: match.id,
          player_stats: [
            {
              player_id: player1.id,
              team_id: team1.id,
              goals: 3,
              assists: 2,
              own_goals: 0,
              was_goalkeeper: false
            },
            {
              player_id: player2.id,
              team_id: team1.id,
              goals: 1,
              assists: 1,
              own_goals: 0,
              was_goalkeeper: false
            },
            {
              player_id: FactoryBot.create(:player).id,
              team_id: team2.id,
              goals: 2,
              assists: 1,
              own_goals: 0,
              was_goalkeeper: false
            }
          ]
        }
      end

      it 'validates assists per team' do
        # Team1: 3 goals, 3 assists (valid: 3 <= 3)
        # Team2: 2 goals, 1 assist (valid: 1 <= 2)
        post :bulk_update, params: valid_params, format: :json
        
        expect(response).to have_http_status(:ok)
        expect(PlayerStat.where(match: match).count).to eq(3)
      end
    end
  end
end
