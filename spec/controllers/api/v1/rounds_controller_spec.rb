# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::RoundsController, type: :controller do
  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: 1 }
    })
    request.headers['Authorization'] = 'Bearer valid_token'
  end

  describe '#index' do
    let!(:rounds) { FactoryBot.create_list(:round, 5, :with_championship) }

    it 'lists all rounds' do
      get :index, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
      # Check that our created rounds are in the response
      round_ids = json_response['data'].map { |r| r['id'] }
      expect(round_ids).to include(*rounds.map(&:id))
    end

    it 'supports pagination' do
      get :index, params: { page: 1, per_page: 2 }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['data'].length).to eq(2)
      expect(json_response['meta']['total']).to be >= 5
    end

    it 'supports includes for eager loading' do
      get :index, params: { include: 'championship' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      # Verify that includes parameter is accepted (actual eager loading is tested in CollectionQuery)
      expect(json_response).to have_key('data')
    end

    it 'supports nested includes' do
      get :index, params: { include: 'matches.team_1' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
    end

    it 'supports multiple includes' do
      get :index, params: { include: 'championship,matches' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
    end
  end

  describe '#show' do
    let(:round) { FactoryBot.create(:round, :with_championship) }

    it 'returns round details' do
      get :show, params: { id: round.id }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['id']).to eq(round.id)
      expect(json_response['name']).to eq(round.name)
    end

    it 'supports sparse fieldsets' do
      get :show, params: { id: round.id, fields: 'id,name' }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response.keys).to contain_exactly('id', 'name')
    end
  end

  describe '#create' do
    let(:championship) { FactoryBot.create(:championship) }

    context 'with valid params' do
      let(:valid_params) do
        {
          round: {
            name: 'Round 1',
            round_date: '2025-01-01',
            championship_id: championship.id
          }
        }
      end

      it 'creates a new round' do
        expect {
          post :create, params: valid_params, format: :json
        }.to change(Round, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Round 1')
        expect(json_response['championship_id']).to eq(championship.id)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          round: {
            name: '',
            championship_id: championship.id
          }
        }
      end

      it 'does not create a round' do
        expect {
          post :create, params: invalid_params, format: :json
        }.not_to change(Round, :count)
        
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:round) { FactoryBot.create(:round, :with_championship, name: 'Old Name') }

    context 'with valid params' do
      it 'updates the round' do
        patch :update, params: { id: round.id, round: { name: 'Updated Name' } }, format: :json
        
        expect(response).to have_http_status(:ok)
        expect(round.reload.name).to eq('Updated Name')
        
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable_entity' do
        patch :update, params: { id: round.id, round: { name: '' } }, format: :json
        
        expect(response).to have_http_status(:unprocessable_content)
        expect(round.reload.name).to eq('Old Name')
      end
    end
  end

  describe '#destroy' do
    let!(:round) { FactoryBot.create(:round, :with_championship) }

    it 'deletes the round' do
      expect {
        delete :destroy, params: { id: round.id }, format: :json
      }.to change(Round, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#statistics' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:player) { FactoryBot.create(:player) }
    let!(:player_round) { FactoryBot.create(:player_round, player: player, round: round) }

    before do
      FactoryBot.create(:player_stat, player: player, team: team1, match: match, goals: 2, assists: 1, own_goals: 0)
    end

    it 'returns round statistics' do
      get :statistics, params: { id: round.id }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to be_a(Hash)
      # RoundStatistics returns hash with integer keys, but JSON serialization converts to strings
      # Check if stats exist for the player (could be string or integer key)
      player_key = json_response.keys.find { |k| k.to_i == player.id } || player.id.to_s
      expect(json_response).to have_key(player_key)
      player_stats = json_response[player_key]
      expect(player_stats).to be_present
      # JSON converts symbols to strings
      expect(player_stats['goals'] || player_stats[:goals]).to eq(2)
      expect(player_stats['assists'] || player_stats[:assists]).to eq(1)
    end
  end
end
