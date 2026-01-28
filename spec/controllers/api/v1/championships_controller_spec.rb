# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ChampionshipsController, type: :controller do
<<<<<<< HEAD
  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: 1 }
    })
    request.headers['Authorization'] = 'Bearer valid_token'
  end

  let(:championship_sample) { FactoryBot.create(:championship) }

  describe '#index' do
    let!(:championship1) { FactoryBot.create(:championship) }
    let!(:championship2) { FactoryBot.create(:championship) }

    it 'returns championships successfully' do
      get :index, format: :json
      expect(response).to have_http_status(:success)
    end

    it 'returns championships with pagination meta' do
      get :index, format: :json
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('data')
      expect(json_response).to have_key('meta')
      expect(json_response['meta']).to have_key('total')
      expect(json_response['meta']).to have_key('page')
      expect(json_response['meta']).to have_key('per_page')
      expect(json_response['meta']).to have_key('total_pages')
    end

    context 'with includes' do
      before do
        FactoryBot.create(:round, championship: championship1)
      end

      it 'applies includes when specified' do
        get :index, params: { include: 'rounds' }, format: :json
        expect(response).to have_http_status(:success)
      end
    end

    context 'with sparse fieldsets' do
      it 'filters fields when fields param is present' do
        get :index, params: { fields: 'id,name' }, format: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        if json_response['data'].any?
          expect(json_response['data'].first.keys).to include('id', 'name')
        end
      end
    end

    context 'with pagination' do
      it 'paginates results correctly' do
        get :index, params: { page: 1, per_page: 1 }, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['meta']['per_page']).to eq(1)
      end
    end
  end

  describe '#show' do
    it 'returns championship details' do
      get :show, params: { id: championship_sample.id }, format: :json
      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['id']).to eq(championship_sample.id)
      expect(json_response['name']).to eq(championship_sample.name)
    end

    context 'with sparse fieldsets' do
      it 'filters fields when fields param is present' do
        get :show, params: { id: championship_sample.id, fields: 'id,name' }, format: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response.keys).to contain_exactly('id', 'name')
        expect(json_response).not_to have_key('description')
      end
    end

    context 'without sparse fieldsets' do
      it 'returns all fields when fields param is not present' do
        get :show, params: { id: championship_sample.id }, format: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('name')
        expect(json_response).to have_key('description')
      end
    end

    context 'when championship does not exist' do
      it 'returns 404 and error message' do
        non_existent_id = (Championship.maximum(:id) || 0) + 99_999
        get :show, params: { id: non_existent_id }, format: :json
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq('error' => 'Championship not found')
      end
    end
=======
  let(:championship_sample) { FactoryBot.create(:championship) }

  describe '#index' do
    it 'assigns @championships' do
      get :index, format: :json
      expect(response).to have_http_status(:success)
    end
>>>>>>> main
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
        expect(response).to have_http_status(:created)
      end
<<<<<<< HEAD

      it 'returns created championship' do
        perform_request
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('La Liga')
      end
=======
>>>>>>> main
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
<<<<<<< HEAD
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns errors' do
        perform_request
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('name')
=======
        expect(response).to have_http_status(:unprocessable_entity)
>>>>>>> main
      end
    end
  end

  describe '#update' do
<<<<<<< HEAD
    context 'with valid params' do
      it 'updates the championship' do
        patch :update, params: { id: championship_sample.id, championship: { name: 'Updated' } }, format: :json
        expect(championship_sample.reload.name).to eq('Updated')
        expect(response).to have_http_status(:success)
      end

      it 'returns updated championship' do
        patch :update, params: { id: championship_sample.id, championship: { name: 'Updated' } }, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Updated')
      end
    end

    context 'with invalid params' do
      it 'does not update the championship' do
        original_name = championship_sample.name
        patch :update, params: { id: championship_sample.id, championship: { name: '' } }, format: :json
        expect(championship_sample.reload.name).to eq(original_name)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns errors' do
        patch :update, params: { id: championship_sample.id, championship: { name: '' } }, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('name')
      end
=======
    it 'updates the championship' do
      patch :update, params: { id: championship_sample.id, championship: { name: 'Updated' } }, format: :json
      expect(championship_sample.reload.name).to eq('Updated')
>>>>>>> main
    end
  end

  describe '#destroy' do
    it 'destroys the requested championship' do
      championship = FactoryBot.create(:championship)
      expect { delete :destroy, params: { id: championship.id }, format: :json }.to change(Championship, :count).by(-1)
<<<<<<< HEAD
      expect(response).to have_http_status(:no_content)
=======
>>>>>>> main
    end
  end
end
