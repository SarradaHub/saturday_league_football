# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ChampionshipsController, type: :controller do
  let(:current_user) { FactoryBot.create(:user, external_id: '1', email: 'test.user@example.com') }
  let(:championship_sample) { FactoryBot.create(:championship, user: current_user) }
  let(:json_response) { JSON.parse(response.body) }

  def perform_request(action, params: {})
    get action, params: params, format: :json
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
    let!(:championships) { FactoryBot.create_list(:championship, 2, user: current_user) }

    before { perform_request(:index) }

    it 'returns championships successfully' do
      expect(response).to have_http_status(:success)
    end

    it 'returns data and meta' do
      expect(json_response).to have_key('data')
      expect(json_response).to have_key('meta')
    end

    it 'returns pagination meta' do
      expect(json_response['meta'].keys).to include('total', 'page', 'per_page', 'total_pages')
    end

    it 'returns at least created championships' do
      expect(json_response['data'].length).to be >= championships.length
    end

    context 'with includes' do
      before do
        FactoryBot.create(:round, championship: championships.first)
      end

      it 'applies includes when specified' do
        perform_request(:index, params: { include: 'rounds' })
        expect(response).to have_http_status(:success)
      end
    end

    context 'with sparse fieldsets' do
      before { perform_request(:index, params: { fields: 'id,name' }) }

      it 'returns ok' do
        expect(response).to have_http_status(:success)
      end

      it 'filters fields when fields param is present' do
        expect(json_response['data'].first.keys).to include('id', 'name')
      end
    end

    context 'with pagination' do
      before { perform_request(:index, params: { page: 1, per_page: 1 }) }

      it 'paginates results correctly' do
        expect(json_response['data'].length).to eq(1)
      end

      it 'returns per_page in meta' do
        expect(json_response['meta']['per_page']).to eq(1)
      end
    end
  end

  describe '#show' do
    before { perform_request(:show, params: { id: championship_sample.id }) }

    it 'returns championship details' do
      expect(response).to have_http_status(:success)
    end

    it 'includes id and name' do
      expect(json_response['id']).to eq(championship_sample.id)
      expect(json_response['name']).to eq(championship_sample.name)
    end

    context 'with sparse fieldsets' do
      before { perform_request(:show, params: { id: championship_sample.id, fields: 'id,name' }) }

      it 'filters fields when fields param is present' do
        expect(json_response.keys).to contain_exactly('id', 'name')
      end

      it 'omits description' do
        expect(json_response).not_to have_key('description')
      end
    end

    context 'without sparse fieldsets' do
      before { perform_request(:show, params: { id: championship_sample.id }) }

      it 'returns all fields when fields param is not present' do
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('name')
        expect(json_response).to have_key('description')
      end
    end

    context 'when championship does not exist' do
      let(:non_existent_id) { (Championship.maximum(:id) || 0) + 99_999 }

      before { perform_request(:show, params: { id: non_existent_id }) }

      it 'returns 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        expect(json_response).to eq('error' => 'Championship not found')
      end
    end
  end

  describe '#summary' do
    before { perform_request(:summary, params: { id: championship_sample.id }) }

    it 'returns ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns only summary fields' do
      expected_keys = %w[id name min_players_per_team max_players_per_team rounds_count players_count created_at]
      expect(json_response.keys).to match_array(expected_keys)
    end

    it 'does not include rounds or players arrays' do
      expect(json_response).not_to have_key('rounds')
      expect(json_response).not_to have_key('players')
    end

    it 'includes id and name' do
      expect(json_response['id']).to eq(championship_sample.id)
      expect(json_response['name']).to eq(championship_sample.name)
    end

    context 'when championship does not exist' do
      let(:non_existent_id) { (Championship.maximum(:id) || 0) + 99_999 }

      before { perform_request(:summary, params: { id: non_existent_id }) }

      it 'returns 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        expect(json_response).to have_key('error')
      end
    end
  end

  describe '#create' do
    subject(:perform_request) { post :create, params: { championship: params }, format: :json }

    context 'with valid params' do
      let(:params) do
        {
          name: 'La Liga',
          min_players_per_team: 5,
          max_players_per_team: 10
        }
      end

      it 'creates a new championship' do
        expect { perform_request }.to change(Championship, :count).by(1)
      end

      it 'returns created status' do
        perform_request
        expect(response).to have_http_status(:created)
      end

      it 'returns created championship' do
        perform_request
        expect(json_response['name']).to eq('La Liga')
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          name: '',
          min_players_per_team: 5,
          max_players_per_team: 10
        }
      end

      it 'does not create a new championship' do
        expect { perform_request }.not_to change(Championship, :count)
      end

      it 'returns unprocessable status' do
        perform_request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns errors' do
        perform_request
        expect(json_response).to have_key('name')
      end
    end
  end

  describe '#update' do
    context 'with valid params' do
      before { patch :update, params: { id: championship_sample.id, championship: { name: 'Updated' } }, format: :json }

      it 'updates the championship' do
        expect(championship_sample.reload.name).to eq('Updated')
      end

      it 'returns success status' do
        expect(response).to have_http_status(:success)
      end

      it 'returns updated championship' do
        expect(json_response['name']).to eq('Updated')
      end
    end

    context 'with invalid params' do
      let(:original_name) { championship_sample.name }

      before { patch :update, params: { id: championship_sample.id, championship: { name: '' } }, format: :json }

      it 'does not update the championship' do
        expect(championship_sample.reload.name).to eq(original_name)
      end

      it 'returns unprocessable status' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns errors' do
        expect(json_response).to have_key('name')
      end
    end
  end

  describe '#destroy' do
    it 'destroys the requested championship' do
      championship = FactoryBot.create(:championship, user: current_user)
      expect { delete :destroy, params: { id: championship.id }, format: :json }
        .to change(Championship, :count).by(-1)
    end

    it 'returns no content status' do
      championship = FactoryBot.create(:championship, user: current_user)
      delete :destroy, params: { id: championship.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end
end
