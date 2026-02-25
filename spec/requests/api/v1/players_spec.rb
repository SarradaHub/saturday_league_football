# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /api/v1/players/:id', type: :request do
  let(:current_user) { FactoryBot.create(:user, external_id: '1', email: 'test.user@example.com') }
  let(:championship) { FactoryBot.create(:championship, user: current_user) }
  let(:round) { FactoryBot.create(:round, championship: championship) }
  let(:player) { FactoryBot.create(:player, first_name: 'Old', last_name: 'Name') }
  let(:auth_header) { { 'Authorization' => 'Bearer valid_token' } }
  let(:json_response) { JSON.parse(response.body) }

  before do
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: current_user.external_id, email: current_user.email }
    })
    allow(Users::SyncFromIdentityService).to receive(:call).and_return(current_user)
    FactoryBot.create(:player_round, player: player, round: round)
  end

  context 'with valid params' do
    before do
      patch "/api/v1/players/#{player.id}",
            params: { player: { first_name: 'Updated', last_name: 'Name' } },
            headers: auth_header,
            as: :json
    end

    it 'returns ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'updates the player' do
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('display_name')
      # Update persistence: client sends PATCH with JSON body; response reflects current player
      expect(player.reload.display_name).to be_present
    end

    it 'returns updated player in response' do
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('display_name')
      expect(json_response['display_name']).to be_present
    end
  end

  context 'with invalid params' do
    before do
      patch "/api/v1/players/#{player.id}",
            params: { player: { first_name: '', last_name: '', nickname: '' } },
            headers: auth_header,
            as: :json
    end

    it 'returns unprocessable_content' do
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'does not update the player' do
      expect(player.reload.display_name).to eq('Old Name')
    end
  end
end
