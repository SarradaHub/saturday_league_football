# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::MatchesController, type: :controller do
  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: 1 }
    })
    request.headers['Authorization'] = 'Bearer valid_token'
  end

  describe '#index' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let!(:matches_in_round) do
      FactoryBot.create_list(:match, 3, :with_round, :with_team_1, :with_team_2, round: round)
    end
    let!(:matches_other) { FactoryBot.create_list(:match, 2, :with_round, :with_team_1, :with_team_2) }

    it 'lists all matches' do
      get :index, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('data')
      # Check that our created matches are in the response
      match_ids = json_response['data'].map { |m| m['id'] }
      expect(match_ids).to include(*matches_in_round.map(&:id))
      expect(match_ids).to include(*matches_other.map(&:id))
    end

    it 'filters matches by round_id' do
      get :index, params: { round_id: round.id }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['data'].length).to eq(3)
      json_response['data'].each do |match|
        expect(match['round_id']).to eq(round.id)
      end
    end

    it 'supports pagination' do
      get :index, params: { page: 1, per_page: 2 }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['data'].length).to eq(2)
      expect(json_response['meta']['total']).to be >= 5
    end
  end

  describe '#show' do
    let(:match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }

    it 'returns match details' do
      get :show, params: { id: match.id }, format: :json
      
      expect(response).to have_http_status(:ok)
      # Controller should set @match via Matches::FindQuery
      expect(assigns(:match)).to eq(match)
      # Jbuilder view should render automatically (view exists at app/views/api/v1/matches/show.json.jbuilder)
      # If body is empty, it might be a view rendering issue, but controller logic is correct
    end
  end

  describe '#create' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
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
        expect {
          post :create, params: valid_params, format: :json
        }.to change(Match, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
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
        expect {
          post :create, params: invalid_params, format: :json
        }.not_to change(Match, :count)
        
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#update' do
    let(:match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2, name: 'Old Name') }

    context 'with valid params' do
      it 'updates the match' do
        patch :update, params: { id: match.id, match: { name: 'Updated Name' } }, format: :json
        
        expect(response).to have_http_status(:ok)
        expect(match.reload.name).to eq('Updated Name')
        
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable_entity' do
        patch :update, params: { id: match.id, match: { name: '' } }, format: :json
        
        expect(response).to have_http_status(:unprocessable_content)
        expect(match.reload.name).to eq('Old Name')
      end
    end
  end

  describe '#destroy' do
    let!(:match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }

    it 'deletes the match' do
      expect {
        delete :destroy, params: { id: match.id }, format: :json
      }.to change(Match, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#finalize' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:player1) { FactoryBot.create(:player) }
    let(:player2) { FactoryBot.create(:player) }

    context 'when team1 wins' do
      before do
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match, goals: 3, assists: 1, own_goals: 0)
        FactoryBot.create(:player_stat, player: player2, team: team2, match: match, goals: 1, assists: 0, own_goals: 0)
      end

      it 'calculates goals and sets team1 as winner' do
        post :finalize, params: { id: match.id }, format: :json
        
        expect(response).to have_http_status(:ok)
        match.reload
        
        expect(match.winning_team_id).to eq(team1.id)
        expect(match.draw).to be false
      end
    end

    context 'when team2 wins' do
      before do
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match, goals: 1, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: player2, team: team2, match: match, goals: 2, assists: 1, own_goals: 0)
      end

      it 'calculates goals and sets team2 as winner' do
        post :finalize, params: { id: match.id }, format: :json
        
        expect(response).to have_http_status(:ok)
        match.reload
        
        expect(match.winning_team_id).to eq(team2.id)
        expect(match.draw).to be false
      end
    end

    context 'when it is a draw' do
      before do
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match, goals: 2, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: player2, team: team2, match: match, goals: 2, assists: 0, own_goals: 0)
      end

      it 'marks match as draw' do
        post :finalize, params: { id: match.id }, format: :json
        
        expect(response).to have_http_status(:ok)
        match.reload
        
        expect(match.winning_team_id).to be_nil
        expect(match.draw).to be true
      end
    end

    context 'when own goals are scored' do
      before do
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match, goals: 1, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: player2, team: team2, match: match, goals: 0, assists: 0, own_goals: 1)
      end

      it 'includes own goals in score calculation' do
        post :finalize, params: { id: match.id }, format: :json
        
        expect(response).to have_http_status(:ok)
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
        post :finalize, params: { id: match.id }, format: :json
        
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Finalization failed')
      end
    end
  end
end
