# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ChampionshipsController, type: :controller do
  let(:championship_sample) { FactoryBot.create(:championship) }

  describe '#index' do
    it 'assigns @championships' do
      get :index, format: :json
      expect(response).to have_http_status(:success)
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
        expect(response).to have_http_status(:created)
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
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe '#update' do
    it 'updates the championship' do
      patch :update, params: { id: championship_sample.id, championship: { name: 'Updated' } }, format: :json
      expect(championship_sample.reload.name).to eq('Updated')
    end
  end

  describe '#destroy' do
    it 'destroys the requested championship' do
      championship = FactoryBot.create(:championship)
      expect { delete :destroy, params: { id: championship.id }, format: :json }.to change(Championship, :count).by(-1)
    end
  end
end
