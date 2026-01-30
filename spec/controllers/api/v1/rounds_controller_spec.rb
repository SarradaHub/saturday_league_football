# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ScatteredSetup

RSpec.describe Api::V1::RoundsController, type: :controller do
  let(:current_user) { FactoryBot.create(:user, external_id: '1', email: 'test.user@example.com') }
  let(:championship) { FactoryBot.create(:championship, user: current_user) }
  let(:json_response) { JSON.parse(response.body) }

  def perform_get(action, params: {})
    get action, params: params, format: :json
  end

  def perform_post(action, params: {})
    post action, params: params, format: :json
  end

  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: current_user.external_id, email: current_user.email }
    })
    allow(Users::SyncFromIdentityService).to receive(:call).and_return(current_user)
    request.headers['Authorization'] = 'Bearer valid_token'
  end

  describe '#index' do
    let!(:rounds) { FactoryBot.create_list(:round, 5, championship: championship) }

    before { perform_get(:index, params: { per_page: 100 }) }

    it 'lists all rounds' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns data array' do
      expect(json_response).to have_key('data')
    end

    it 'includes created rounds' do
      round_ids = json_response['data'].map { |r| r['id'] }
      expect(round_ids).to include(*rounds.map(&:id))
    end

    it 'supports pagination' do
      perform_get(:index, params: { page: 1, per_page: 2 })
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(2)
    end

    it 'returns total for pagination' do
      perform_get(:index, params: { page: 1, per_page: 2 })
      expect(json_response['meta']['total']).to be >= 5
    end

    it 'supports includes for eager loading' do
      perform_get(:index, params: { include: 'championship' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports nested includes' do
      perform_get(:index, params: { include: 'matches.team_1' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports multiple includes' do
      perform_get(:index, params: { include: 'championship,matches' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end
  end

  describe '#show' do
    let(:round) { FactoryBot.create(:round, championship: championship) }

    before { perform_get(:show, params: { id: round.id }) }

    it 'returns round details' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns id and name' do
      expect(json_response['id']).to eq(round.id)
      expect(json_response['name']).to eq(round.name)
    end

    it 'supports sparse fieldsets' do
      perform_get(:show, params: { id: round.id, fields: 'id,name' })
      expect(response).to have_http_status(:ok)
      expect(json_response.keys).to contain_exactly('id', 'name')
    end
  end

  describe '#create' do
    let(:championship) { FactoryBot.create(:championship, user: current_user) }

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
        expect { perform_post(:create, params: valid_params) }
          .to change(Round, :count).by(1)
      end

      it 'returns created status' do
        perform_post(:create, params: valid_params)
        expect(response).to have_http_status(:created)
      end

      it 'returns created round' do
        perform_post(:create, params: valid_params)
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
        expect { perform_post(:create, params: invalid_params) }
          .not_to change(Round, :count)
      end

      it 'returns unprocessable status' do
        perform_post(:create, params: invalid_params)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:round) { FactoryBot.create(:round, championship: championship, name: 'Old Name') }

    context 'with valid params' do
      before { patch :update, params: { id: round.id, round: { name: 'Updated Name' } }, format: :json }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the round' do
        expect(round.reload.name).to eq('Updated Name')
      end

      it 'returns updated round' do
        expect(json_response['name']).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      before { patch :update, params: { id: round.id, round: { name: '' } }, format: :json }

      it 'returns unprocessable_entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not update the round' do
        expect(round.reload.name).to eq('Old Name')
      end
    end
  end

  describe '#destroy' do
    let!(:round) { FactoryBot.create(:round, championship: championship) }

    it 'deletes the round' do
      expect { delete :destroy, params: { id: round.id }, format: :json }
        .to change(Round, :count).by(-1)
    end

    it 'returns no content status' do
      delete :destroy, params: { id: round.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#statistics' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:teams) { FactoryBot.create_list(:team, 2, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: teams.first, team_2: teams.last) }
    let(:player) { FactoryBot.create(:player) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
      FactoryBot.create(:player_stat, player: player, team: teams.first, match: match, goals: 2, assists: 1, own_goals: 0)
perform_get(:statistics, params: { id: round.id })
    end


    it 'returns round statistics' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns stats hash' do
      expect(json_response).to be_a(Hash)
    end

    it 'includes player stats in response' do
      # RoundStatistics returns hash with integer keys, but JSON serialization converts to strings
      # Check if stats exist for the player (could be string or integer key)
      player_key = json_response.keys.find { |k| k.to_i == player.id } || player.id.to_s
      expect(json_response).to have_key(player_key)
      player_stats = json_response[player_key]
      expect(player_stats).to be_present
    end

    it 'returns goals and assists' do
      player_key = json_response.keys.find { |k| k.to_i == player.id } || player.id.to_s
      player_stats = json_response[player_key]
      expect(player_stats['goals'] || player_stats[:goals]).to eq(2)
      expect(player_stats['assists'] || player_stats[:assists]).to eq(1)
    end
  end
end

# rubocop:enable RSpec/ScatteredSetup
