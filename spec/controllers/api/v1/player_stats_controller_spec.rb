# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers

RSpec.describe Api::V1::PlayerStatsController, type: :controller do
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
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let!(:player_stats) do
      Array.new(5) do
        FactoryBot.create(:player_stat, player: FactoryBot.create(:player), team: team1, match: match,
                                        goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false)
      end
    end

    before { perform_get(:index) }

    it 'lists all player stats' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns data and meta' do
      expect(json_response).to have_key('data')
      expect(json_response).to have_key('meta')
    end

    it 'includes created stats in total count' do
      expect(json_response['meta']['total']).to be >= player_stats.length
    end

    it 'supports pagination' do
      perform_get(:index, params: { page: 1, per_page: 2 })
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(2)
    end

    it 'returns total with pagination' do
      perform_get(:index, params: { page: 1, per_page: 2 })
      expect(json_response['meta']['total']).to be >= player_stats.length
    end

    it 'supports includes for eager loading' do
      perform_get(:index, params: { include: 'player' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports nested includes' do
      perform_get(:index, params: { include: 'player.teams,match.round' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports multiple includes' do
      perform_get(:index, params: { include: 'player,team,match' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports sparse fieldsets' do
      perform_get(:index, params: { fields: 'id,goals,assists' })
      expect(response).to have_http_status(:ok)
      stat_data = json_response['data'].first
      expect(stat_data.keys).to include('id', 'goals', 'assists')
    end

    it 'omits fields not requested' do
      perform_get(:index, params: { fields: 'id,goals,assists' })
      stat_data = json_response['data'].first
      expect(stat_data).not_to have_key('own_goals')
      expect(stat_data).not_to have_key('was_goalkeeper')
    end

    it 'supports sparse fieldsets with multiple fields' do
      perform_get(:index, params: { fields: 'id,goals,assists,own_goals' })
      expect(response).to have_http_status(:ok)
      stat_data = json_response['data'].first
      expect(stat_data.keys).to include('id', 'goals', 'assists', 'own_goals')
    end

    it 'omits unspecified fields from multiple fieldsets' do
      perform_get(:index, params: { fields: 'id,goals,assists,own_goals' })
      stat_data = json_response['data'].first
      expect(stat_data).not_to have_key('was_goalkeeper')
    end
  end

  describe '#show' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:player_stat) { FactoryBot.create(:player_stat, player: FactoryBot.create(:player), team: team1, match: match) }

    before { perform_get(:show, params: { id: player_stat.id }) }

    it 'returns player stat details' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns id and goals' do
      expect(json_response['id']).to eq(player_stat.id)
      expect(json_response['goals']).to eq(player_stat.goals)
    end
  end

  describe '#create' do
    let(:player) { FactoryBot.create(:player) }
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: FactoryBot.create(:team, round: round)) }

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
        expect { perform_post(:create, params: valid_params) }
          .to change(PlayerStat, :count).by(1)
      end

      it 'returns created status' do
        perform_post(:create, params: valid_params)
        expect(response).to have_http_status(:created)
      end

      it 'returns created goals and assists' do
        perform_post(:create, params: valid_params)
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
        expect { perform_post(:create, params: invalid_params) }
          .not_to change(PlayerStat, :count)
      end

      it 'returns unprocessable status' do
        perform_post(:create, params: invalid_params)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match_record) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:player_stat) { FactoryBot.create(:player_stat, player: FactoryBot.create(:player), team: team1, match: match_record, goals: 1, assists: 0, own_goals: 0) }

    context 'with valid params' do
      before { patch :update, params: { id: player_stat.id, player_stat: { goals: 3 } }, format: :json }

      it 'updates the player stat' do
        expect(response).to have_http_status(:ok)
        expect(player_stat.reload.goals).to eq(3)
      end

      it 'returns updated goals' do
        expect(json_response['goals']).to eq(3)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          id: player_stat.id,
          player_stat: {
            goals: player_stat.goals,
            assists: 1,
            own_goals: 1,
            was_goalkeeper: player_stat.was_goalkeeper
          }
        }
      end

      before { patch :update, params: invalid_params, format: :json }

      it 'returns unprocessable_entity when assists on own goals' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns validation errors' do
        expect(json_response['errors']).to be_present
      end

      it 'mentions assists or own goals in errors' do
        error_messages = json_response['errors'].join(' ')
        expect(error_messages).to match(/assist|gol contra/i)
      end
    end
  end

  describe '#destroy' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let!(:player_stat) { FactoryBot.create(:player_stat, player: FactoryBot.create(:player), team: team1, match: match) }

    it 'deletes the player stat' do
      expect { delete :destroy, params: { id: player_stat.id }, format: :json }
        .to change(PlayerStat, :count).by(-1)
    end

    it 'returns no content status' do
      delete :destroy, params: { id: player_stat.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#by_match' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:teams) { FactoryBot.create_list(:team, 2, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: teams.first, team_2: teams.last) }
    let!(:stats_in_match) do
      FactoryBot.create_list(:player_stat, 3, player: FactoryBot.create(:player), team: teams.first, match: match,
                                           goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false)
    end
    let!(:stats_other) do
      other_match = FactoryBot.create(:match, round: round, team_1: teams.first, team_2: teams.last)
      FactoryBot.create_list(:player_stat, 2, player: FactoryBot.create(:player), team: teams.last, match: other_match,
                                           goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false)
    end

    it 'returns player stats for a specific match' do
      perform_get(:by_match, params: { match_id: match.id })
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(stats_in_match.length)
    end

    it 'supports pagination' do
      perform_get(:by_match, params: { match_id: match.id, page: 1, per_page: 2 })
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(2)
    end

    it 'returns total for match stats' do
      perform_get(:by_match, params: { match_id: match.id, page: 1, per_page: 2 })
      expect(json_response['meta']['total']).to eq(stats_in_match.length)
    end

    it 'supports includes for eager loading' do
      perform_get(:by_match, params: { match_id: match.id, include: 'player' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports nested includes' do
      perform_get(:by_match, params: { match_id: match.id, include: 'player.teams,match.round' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports multiple includes' do
      perform_get(:by_match, params: { match_id: match.id, include: 'player,team,match' })
      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('data')
    end

    it 'supports sparse fieldsets' do
      perform_get(:by_match, params: { match_id: match.id, fields: 'id,goals,assists' })
      expect(response).to have_http_status(:ok)
      stat_data = json_response['data'].first
      expect(stat_data.keys).to include('id', 'goals', 'assists')
    end

    it 'omits fields not requested for by_match' do
      perform_get(:by_match, params: { match_id: match.id, fields: 'id,goals,assists' })
      stat_data = json_response['data'].first
      expect(stat_data).not_to have_key('own_goals')
      expect(stat_data).not_to have_key('was_goalkeeper')
    end

    it 'supports sparse fieldsets with multiple fields' do
      perform_get(:by_match, params: { match_id: match.id, fields: 'id,goals,assists,own_goals,was_goalkeeper' })
      expect(response).to have_http_status(:ok)
      stat_data = json_response['data'].first
      expect(stat_data.keys).to include('id', 'goals', 'assists', 'own_goals', 'was_goalkeeper')
    end

    it 'returns only stats for match id' do
      perform_get(:by_match, params: { match_id: match.id })
      match_ids = json_response['data'].map { |stat| stat['match_id'] }
      expect(match_ids).to all(eq(match.id))
    end

    it 'excludes stats from other matches' do
      perform_get(:by_match, params: { match_id: match.id })
      response_ids = json_response['data'].map { |stat| stat['id'] }
      expect(response_ids & stats_other.map(&:id)).to be_empty
    end
  end

  describe '#bulk_update' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:teams) { FactoryBot.create_list(:team, 2, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: teams.first, team_2: teams.last) }
    let(:players) { FactoryBot.create_list(:player, 2) }

    context 'with valid stats' do
      let(:valid_params) do
        {
          match_id: match.id,
          player_stats: [
            {
              player_id: players.first.id,
              team_id: teams.first.id,
              goals: 2,
              assists: 1,
              own_goals: 0,
              was_goalkeeper: false
            },
            {
              player_id: players.last.id,
              team_id: teams.last.id,
              goals: 1,
              assists: 0,
              own_goals: 0,
              was_goalkeeper: true
            }
          ]
        }
      end

      it 'creates player stats in bulk' do
        expect { perform_post(:bulk_update, params: valid_params) }
          .to change(PlayerStat, :count).by(2)
      end

      it 'returns ok status' do
        perform_post(:bulk_update, params: valid_params)
        expect(response).to have_http_status(:ok)
      end

      it 'returns array of created stats' do
        perform_post(:bulk_update, params: valid_params)
        expect(json_response).to be_an(Array)
        expect(json_response.length).to eq(2)
      end

      it 'replaces existing stats for the match' do
        FactoryBot.create(:player_stat, match: match, player: players.first, team: teams.first, goals: 5)
        perform_post(:bulk_update, params: valid_params)
        expect(response).to have_http_status(:ok)
        expect(PlayerStat.where(match: match).count).to eq(2)
      end

      it 'updates existing stat values' do
        FactoryBot.create(:player_stat, match: match, player: players.first, team: teams.first, goals: 5)
        perform_post(:bulk_update, params: valid_params)
        expect(PlayerStat.where(match: match, player: players.first).first.goals).to eq(2)
      end
    end

    context 'with invalid assists (assists on own goals)' do
      let(:invalid_params) do
        {
          match_id: match.id,
          player_stats: [
            {
              player_id: players.first.id,
              team_id: teams.first.id,
              goals: 0,
              assists: 1,
              own_goals: 1, # Cannot have assists on own goals
              was_goalkeeper: false
            }
          ]
        }
      end

      it 'returns error' do
        perform_post(:bulk_update, params: invalid_params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to be_present
      end
    end

    context 'with invalid assists (assists exceed goals)' do
      let(:invalid_params) do
        {
          match_id: match.id,
          player_stats: [
            {
              player_id: players.first.id,
              team_id: teams.first.id,
              goals: 2,
              assists: 3, # Assists cannot exceed goals
              own_goals: 0,
              was_goalkeeper: false
            }
          ]
        }
      end

      it 'returns error' do
        perform_post(:bulk_update, params: invalid_params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to be_present
      end
    end

    context 'with multiple teams' do
      let(:valid_params) do
        {
          match_id: match.id,
          player_stats: [
            {
              player_id: players.first.id,
              team_id: teams.first.id,
              goals: 3,
              assists: 2,
              own_goals: 0,
              was_goalkeeper: false
            },
            {
              player_id: players.last.id,
              team_id: teams.first.id,
              goals: 1,
              assists: 1,
              own_goals: 0,
              was_goalkeeper: false
            },
            {
              player_id: FactoryBot.create(:player).id,
              team_id: teams.last.id,
              goals: 2,
              assists: 1,
              own_goals: 0,
              was_goalkeeper: false
            }
          ]
        }
      end

      it 'validates assists per team' do
        perform_post(:bulk_update, params: valid_params)
        expect(response).to have_http_status(:ok)
        expect(PlayerStat.where(match: match).count).to eq(3)
      end
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
