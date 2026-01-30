# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::TeamsController, type: :controller do
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
    let!(:round) { FactoryBot.create(:round, championship: championship) }
    let!(:teams_in_round) { FactoryBot.create_list(:team, 3, round: round) }
    let!(:teams_other) { FactoryBot.create_list(:team, 2, round: FactoryBot.create(:round, championship: championship)) }

    before { perform_get(:index) }

    it 'lists all teams' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns data and meta' do
      expect(json_response).to have_key('data')
      expect(json_response).to have_key('meta')
    end

    it 'includes created teams in total count' do
      expect(json_response['meta']['total']).to be >= (teams_in_round.length + teams_other.length)
    end

    it 'filters teams by round_id' do
      perform_get(:index, params: { round_id: round.id })
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(teams_in_round.length)
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
      perform_get(:index, params: { include: 'round' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports nested includes' do
      perform_get(:index, params: { include: 'round.championship' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports sparse fieldsets' do
      perform_get(:index, params: { fields: 'id,name' })
      expect(response).to have_http_status(:ok)
      team_data = json_response['data'].first
      expect(team_data.keys).to contain_exactly('id', 'name')
    end

    it 'omits round_id in sparse fieldsets' do
      perform_get(:index, params: { fields: 'id,name' })
      team_data = json_response['data'].first
      expect(team_data).not_to have_key('round_id')
    end

    it 'supports sparse fieldsets with multiple fields' do
      perform_get(:index, params: { fields: 'id,name,round_id' })
      expect(response).to have_http_status(:ok)
      team_data = json_response['data'].first
      expect(team_data.keys).to contain_exactly('id', 'name', 'round_id')
    end

    it 'omits created_at in sparse fieldsets' do
      perform_get(:index, params: { fields: 'id,name,round_id' })
      team_data = json_response['data'].first
      expect(team_data).not_to have_key('created_at')
    end
  end

  describe '#show' do
    let(:team) { FactoryBot.create(:team, round: FactoryBot.create(:round, championship: championship)) }

    before { perform_get(:show, params: { id: team.id }) }

    it 'returns team details' do
      expect(response).to have_http_status(:ok)
    end

    it 'assigns @team' do
      expect(assigns(:team)).to eq(team)
    end

    it 'supports sparse fieldsets parameter' do
      perform_get(:show, params: { id: team.id, fields: 'id,name' })
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#create' do
    let(:round) { FactoryBot.create(:round, championship: championship) }

    context 'with valid params' do
      let(:valid_params) do
        {
          team: {
            name: 'New Team',
            round_id: round.id
          }
        }
      end

      it 'creates a new team' do
        expect { perform_post(:create, params: valid_params) }
          .to change(Team, :count).by(1)
      end

      it 'returns created status' do
        perform_post(:create, params: valid_params)
        expect(response).to have_http_status(:created)
      end

      it 'returns created team' do
        perform_post(:create, params: valid_params)
        expect(json_response['name']).to eq('New Team')
        expect(json_response['round_id']).to eq(round.id)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          team: {
            name: '',
            round_id: round.id
          }
        }
      end

      it 'does not create a team' do
        expect { perform_post(:create, params: invalid_params) }
          .not_to change(Team, :count)
      end

      it 'returns unprocessable status' do
        perform_post(:create, params: invalid_params)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:team) { FactoryBot.create(:team, round: FactoryBot.create(:round, championship: championship), name: 'Old Name') }

    context 'with valid params' do
      before { patch :update, params: { id: team.id, team: { name: 'Updated Name' } }, format: :json }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the team' do
        expect(team.reload.name).to eq('Updated Name')
      end

      it 'returns updated team' do
        expect(json_response['name']).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      before { patch :update, params: { id: team.id, team: { name: '' } }, format: :json }

      it 'returns unprocessable_entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not update the team' do
        expect(team.reload.name).to eq('Old Name')
      end
    end
  end

  describe '#destroy' do
    let!(:team) { FactoryBot.create(:team, round: FactoryBot.create(:round, championship: championship)) }

    it 'deletes the team' do
      expect { delete :destroy, params: { id: team.id }, format: :json }
        .to change(Team, :count).by(-1)
    end

    it 'returns no content status' do
      delete :destroy, params: { id: team.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end
end
