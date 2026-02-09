# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/ScatteredSetup, RSpec/ScatteredLet, RSpec/MultipleMemoizedHelpers

RSpec.describe Api::V1::PlayersController, type: :controller do
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
perform_get(:index)
    end


    it 'lists all players' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns data and meta' do
      expect(json_response).to have_key('data')
      expect(json_response).to have_key('meta')
    end

    it 'includes created players in total count' do
      expect(json_response['meta']['total']).to be >= players_in_championship.length
    end

    it 'filters players by championship_id' do
      perform_get(:index, params: { championship_id: championship.id })
      expect(response).to have_http_status(:ok)
      player_ids = json_response['data'].map { |p| p['id'] }
      expect(player_ids).to include(*players_in_championship.map(&:id))
    end

    it 'excludes players from other championships' do
      perform_get(:index, params: { championship_id: championship.id })
      player_ids = json_response['data'].map { |p| p['id'] }
      expect(player_ids).not_to include(*players_other.map(&:id))
    end

    it 'supports pagination' do
      perform_get(:index, params: { page: 1, per_page: 2 })
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(2)
    end

    it 'returns total with pagination' do
      perform_get(:index, params: { page: 1, per_page: 2 })
      expect(json_response['meta']['total']).to be >= 3
    end
  end

  describe '#show' do
    let(:player) { FactoryBot.create(:player) }
    let(:round) { FactoryBot.create(:round, championship: championship) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
perform_get(:show, params: { id: player.id })
    end


    it 'returns player details' do
      expect(response).to have_http_status(:ok)
    end

    it 'assigns @player' do
      expect(assigns(:player)).to eq(player)
    end
  end

  describe '#create' do
    context 'with valid params' do
      let(:valid_params) do
        {
          player: {
            first_name: 'New',
            last_name: 'Player'
          }
        }
      end

      it 'creates a new player' do
        expect { perform_post(:create, params: valid_params) }
          .to change(Player, :count).by(1)
      end

      it 'returns created status' do
        perform_post(:create, params: valid_params)
        expect(response).to have_http_status(:created)
      end

      it 'returns created player' do
        perform_post(:create, params: valid_params)
        expect(json_response['display_name']).to eq('New Player')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          player: {
            first_name: '',
            last_name: '',
            nickname: ''
          }
        }
      end

      it 'does not create a player' do
        expect { perform_post(:create, params: invalid_params) }
          .not_to change(Player, :count)
      end

      it 'returns unprocessable status' do
        perform_post(:create, params: invalid_params)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:player) { FactoryBot.create(:player, first_name: 'Old', last_name: 'Name') }
    let(:round) { FactoryBot.create(:round, championship: championship) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
    end

    context 'with valid params' do
      before { patch :update, params: { id: player.id, player: { first_name: 'Updated', last_name: 'Name' } }, format: :json }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the player' do
        expect(player.reload.display_name).to eq('Updated Name')
      end

      it 'returns updated player' do
        expect(json_response['display_name']).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      before { patch :update, params: { id: player.id, player: { first_name: '', last_name: '', nickname: '' } }, format: :json }

      it 'returns unprocessable_entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not update the player' do
        expect(player.reload.display_name).to eq('Old Name')
      end
    end
  end

  describe '#destroy' do
    let!(:player) { FactoryBot.create(:player) }
    let(:round) do
      championship_without_min = FactoryBot.create(:championship, user: current_user, min_players_per_team: 0)
      FactoryBot.create(:round, championship: championship_without_min)
    end

    before do
      FactoryBot.create(:player_round, player: player, round: round)
    end

    it 'deletes the player' do
      expect { delete :destroy, params: { id: player.id }, format: :json }
        .to change(Player, :count).by(-1)
    end

    it 'returns no content status' do
      delete :destroy, params: { id: player.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#add_to_round' do
    let(:player) { FactoryBot.create(:player) }
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:existing_round) { FactoryBot.create(:round, championship: championship) }

    before do
      FactoryBot.create(:player_round, player: player, round: existing_round)
    end

    it 'adds player to round' do
      expect { perform_post(:add_to_round, params: { id: player.id, round_id: round.id }) }
        .to change(PlayerRound, :count).by(1)
    end

    it 'returns ok when adding to round' do
      perform_post(:add_to_round, params: { id: player.id, round_id: round.id })
      expect(response).to have_http_status(:ok)
    end

    it 'adds the round to player' do
      perform_post(:add_to_round, params: { id: player.id, round_id: round.id })
      expect(player.rounds).to include(round)
    end

    it 'is idempotent - does not add duplicate' do
      FactoryBot.create(:player_round, player: player, round: round)

      expect { perform_post(:add_to_round, params: { id: player.id, round_id: round.id }) }
        .not_to change(PlayerRound, :count)
    end

    it 'returns ok when round already added' do
      FactoryBot.create(:player_round, player: player, round: round)
      perform_post(:add_to_round, params: { id: player.id, round_id: round.id })
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#add_to_team' do
    let(:player) { FactoryBot.create(:player) }
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team) { FactoryBot.create(:team, round: round) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
    end

    it 'adds player to team' do
      expect { perform_post(:add_to_team, params: { id: player.id, team_id: team.id }) }
        .to change(PlayerTeam, :count).by(1)
    end

    it 'returns ok when adding to team' do
      perform_post(:add_to_team, params: { id: player.id, team_id: team.id })
      expect(response).to have_http_status(:ok)
    end

    it 'adds the team to player' do
      perform_post(:add_to_team, params: { id: player.id, team_id: team.id })
      expect(player.teams).to include(team)
    end

    it 'is idempotent - does not add duplicate' do
      FactoryBot.create(:player_team, player: player, team: team)

      expect { perform_post(:add_to_team, params: { id: player.id, team_id: team.id }) }
        .not_to change(PlayerTeam, :count)
    end

    it 'returns ok when team already added' do
      FactoryBot.create(:player_team, player: player, team: team)
      perform_post(:add_to_team, params: { id: player.id, team_id: team.id })
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#match_stats' do
    let(:player) { FactoryBot.create(:player) }
    let(:match_stats_params) do
      { id: player.id, team_id: team.id, round_id: round.id, match_id: match.id }
    end
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: team2) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
      FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 2, assists: 1, own_goals: 0)
perform_get(:match_stats, params: match_stats_params)
    end



    it 'returns player match statistics' do
      expect(response).to have_http_status(:ok)
    end

    it 'includes goals in match' do
      expect(json_response).to have_key('goals_in_match')
      expect(json_response['goals_in_match']).to eq(2)
    end

    it 'includes assists in match' do
      expect(json_response['assists_in_match']).to eq(1)
    end
  end
end

# rubocop:enable RSpec/ScatteredSetup, RSpec/ScatteredLet, RSpec/MultipleMemoizedHelpers
