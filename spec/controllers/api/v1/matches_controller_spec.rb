# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers

RSpec.describe Api::V1::MatchesController, type: :controller do
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
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let!(:matches_in_round) do
      Array.new(3) do
        FactoryBot.create(:match, round: round,
                                  team_1: FactoryBot.create(:team, round: round),
                                  team_2: FactoryBot.create(:team, round: round))
      end
    end
    let!(:matches_other) do
      other_round = FactoryBot.create(:round, championship: championship)
      Array.new(2) do
        FactoryBot.create(:match, round: other_round,
                                  team_1: FactoryBot.create(:team, round: other_round),
                                  team_2: FactoryBot.create(:team, round: other_round))
      end
    end

    before { perform_get(:index) }

    it 'returns ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns data array' do
      expect(json_response).to have_key('data')
    end

    it 'includes matches from all rounds' do
      # Check that our created matches are in the response
      match_ids = json_response['data'].map { |m| m['id'] }
      expect(match_ids).to include(*matches_in_round.map(&:id))
      expect(match_ids).to include(*matches_other.map(&:id))
    end

    it 'filters matches by round_id' do
      perform_get(:index, params: { round_id: round.id })
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(3)
    end

    it 'returns only matches for the round' do
      perform_get(:index, params: { round_id: round.id })
      round_ids = json_response['data'].map { |match| match['round_id'] }
      expect(round_ids).to all(eq(round.id))
    end

    it 'supports pagination' do
      perform_get(:index, params: { page: 1, per_page: 2 })
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(2)
      expect(json_response['meta']['total']).to be >= 5
    end
  end

  describe '#show' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:match) { FactoryBot.create(:match, :with_team_1, :with_team_2, round: round) }

    before { perform_get(:show, params: { id: match.id }) }

    it 'returns match details' do
      expect(response).to have_http_status(:ok)
    end

    it 'assigns @match' do
      expect(assigns(:match)).to eq(match)
    end
  end

  describe '#create' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }

    context 'with valid params' do
      let(:valid_params) do
        {
          match: {
            name: 'Match 1',
            round_id: round.id,
            team_1_id: team1.id,
            team_2_id: team2.id
          }
        }
      end

      it 'creates a new match' do
        expect { perform_post(:create, params: valid_params) }
          .to change(Match, :count).by(1)
      end

      it 'returns created status' do
        perform_post(:create, params: valid_params)
        expect(response).to have_http_status(:created)
      end

      it 'returns created match fields' do
        perform_post(:create, params: valid_params)
        expect(json_response['name']).to eq('Match 1')
        expect(json_response['round_id']).to eq(round.id)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          match: {
            name: '',
            round_id: round.id
          }
        }
      end

      it 'does not create a match' do
        expect { perform_post(:create, params: invalid_params) }
          .not_to change(Match, :count)
      end

      it 'returns unprocessable status' do
        perform_post(:create, params: invalid_params)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:match) { FactoryBot.create(:match, :with_team_1, :with_team_2, round: round, name: 'Old Name') }

    context 'with valid params' do
      before { patch :update, params: { id: match.id, match: { name: 'Updated Name' } }, format: :json }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the match' do
        expect(match.reload.name).to eq('Updated Name')
      end

      it 'returns updated match' do
        expect(json_response['name']).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      before { patch :update, params: { id: match.id, match: { name: '' } }, format: :json }

      it 'returns unprocessable_entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not update the match' do
        expect(match.reload.name).to eq('Old Name')
      end
    end
  end

  describe '#destroy' do
    let!(:round) { FactoryBot.create(:round, championship: championship) }
    let!(:match) { FactoryBot.create(:match, :with_team_1, :with_team_2, round: round) }

    it 'deletes the match' do
      expect { delete :destroy, params: { id: match.id }, format: :json }
        .to change(Match, :count).by(-1)
    end

    it 'returns no content status' do
      delete :destroy, params: { id: match.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#finalize' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:players) { FactoryBot.create_list(:player, 2) }

    context 'when team1 wins' do
      before do
        FactoryBot.create(:player_stat, player: players.first, team: team1, match: match, goals: 3, assists: 1, own_goals: 0)
        FactoryBot.create(:player_stat, player: players.last, team: team2, match: match, goals: 1, assists: 0, own_goals: 0)
        perform_post(:finalize, params: { id: match.id })
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'sets team1 as winner' do
        match.reload
        expect(match.winning_team_id).to eq(team1.id)
        expect(match.draw).to be false
      end
    end

    context 'when team2 wins' do
      before do
        FactoryBot.create(:player_stat, player: players.first, team: team1, match: match, goals: 1, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: players.last, team: team2, match: match, goals: 2, assists: 1, own_goals: 0)
        perform_post(:finalize, params: { id: match.id })
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'sets team2 as winner' do
        match.reload
        expect(match.winning_team_id).to eq(team2.id)
        expect(match.draw).to be false
      end
    end

    context 'when it is a draw' do
      before do
        FactoryBot.create(:player_stat, player: players.first, team: team1, match: match, goals: 2, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: players.last, team: team2, match: match, goals: 2, assists: 0, own_goals: 0)
        perform_post(:finalize, params: { id: match.id })
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'marks match as draw' do
        match.reload
        expect(match.winning_team_id).to be_nil
        expect(match.draw).to be true
      end
    end

    context 'when own goals are scored' do
      before do
        FactoryBot.create(:player_stat, player: players.first, team: team1, match: match, goals: 1, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: players.last, team: team2, match: match, goals: 0, assists: 0, own_goals: 1)
        perform_post(:finalize, params: { id: match.id })
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes own goals in score calculation' do
        match.reload
        # team1 should have 2 goals (1 goal + 1 own goal from team2)
        # team2 should have 0 goals (0 goals + 0 own goals from team1)
        expect(match.winning_team_id).to eq(team1.id)
        expect(match.draw).to be false
      end
    end

    context 'when an error occurs' do
      before do
        allow(Matches::Finalize).to receive(:call).and_raise(StandardError.new('Finalization failed'))
      end

      it 'returns error response' do
        perform_post(:finalize, params: { id: match.id })
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to include('Finalization failed')
      end
    end
  end

  describe '#substitute_player' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:player_to_remove) { FactoryBot.create(:player) }
    let(:replacement_player) { FactoryBot.create(:player) }

    before do
      round.players << player_to_remove
      round.players << replacement_player
      team1.players << player_to_remove
    end

    context 'when substitution is successful' do
      before do
        perform_post(:substitute_player, params: {
          id: match.id,
          player_id: player_to_remove.id,
          replacement_player_id: replacement_player.id,
          team_id: team1.id
        })
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns removed player id and name' do
        expect(json_response['removed_player_id']).to eq(player_to_remove.id)
        expect(json_response['removed_player_name']).to eq(player_to_remove.display_name)
      end

      it 'returns replacement player id and name' do
        expect(json_response['replacement_player_id']).to eq(replacement_player.id)
        expect(json_response['replacement_player_name']).to eq(replacement_player.display_name)
      end

      it 'returns team id and name' do
        expect(json_response['team_id']).to eq(team1.id)
        expect(json_response['team_name']).to eq(team1.name)
      end

      it 'removes player from team' do
        team1.reload
        expect(team1.players).not_to include(player_to_remove)
      end

      it 'adds replacement player to team' do
        team1.reload
        expect(team1.players).to include(replacement_player)
      end
    end

    context 'when player is not in team' do
      before do
        team1.players.delete(player_to_remove)
        perform_post(:substitute_player, params: {
          id: match.id,
          player_id: player_to_remove.id,
          replacement_player_id: replacement_player.id,
          team_id: team1.id
        })
      end

      it 'returns error response' do
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when replacement player is not in round' do
      before do
        round.players.delete(replacement_player)
        perform_post(:substitute_player, params: {
          id: match.id,
          player_id: player_to_remove.id,
          replacement_player_id: replacement_player.id,
          team_id: team1.id
        })
      end

      it 'returns error response' do
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when replacement player is already in match teams' do
      before do
        team2.players << replacement_player
        perform_post(:substitute_player, params: {
          id: match.id,
          player_id: player_to_remove.id,
          replacement_player_id: replacement_player.id,
          team_id: team1.id
        })
      end

      it 'returns error response' do
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when team is not part of match' do
      let(:other_team) { FactoryBot.create(:team, round: round) }

      before do
        perform_post(:substitute_player, params: {
          id: match.id,
          player_id: player_to_remove.id,
          replacement_player_id: replacement_player.id,
          team_id: other_team.id
        })
      end

      it 'returns error response' do
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to be_present
      end
    end
  end

  describe '#summary' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }

    before { perform_get(:summary, params: { id: match.id }) }

    it 'returns ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns only summary fields' do
      expected_keys = %w[id name round_id team_1_id team_2_id winning_team_id draw team_1_goals team_2_goals team_1_name team_2_name created_at]
      expect(json_response.keys).to match_array(expected_keys)
    end

    it 'does not include full team objects or statistics' do
      expect(json_response).not_to have_key('team_1_players')
      expect(json_response).not_to have_key('statistics')
    end

    it 'includes id and name' do
      expect(json_response['id']).to eq(match.id)
      expect(json_response['name']).to eq(match.name)
    end

    context 'when match does not exist' do
      let(:non_existent_id) { (Match.maximum(:id) || 0) + 99_999 }

      before { perform_get(:summary, params: { id: non_existent_id }) }

      it 'returns 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        expect(json_response).to have_key('error')
      end
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
