# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerStats::BulkUpsert do
  subject(:call_result) do
    described_class.call(match_id: match.id, payload: payload)
  end

  let(:match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }
  let(:player1) { FactoryBot.create(:player) }
  let(:player2) { FactoryBot.create(:player) }
  let(:team1) { match.team_1 }
  let(:team2) { match.team_2 }

  describe '#call' do
    context 'with valid payload' do
      let(:payload) do
        [
          {
            player_id: player1.id,
            team_id: team1.id,
            goals: 2,
            assists: 1,
            own_goals: 0,
            was_goalkeeper: false
          },
          {
            player_id: player2.id,
            team_id: team2.id,
            goals: 1,
            assists: 0,
            own_goals: 0,
            was_goalkeeper: true
          }
        ]
      end

      it 'creates player stats' do
        expect {
          call_result
        }.to change(PlayerStat, :count).by(2)
      end

      it 'returns collection of created stats' do
        result = call_result
        
        # Returns ActiveRecord::Relation, convert to array for testing
        expect(result).to respond_to(:to_a)
        result_array = result.to_a
        expect(result_array.length).to eq(2)
        expect(result_array.map(&:player_id)).to contain_exactly(player1.id, player2.id)
      end

      it 'replaces existing stats for the match' do
        FactoryBot.create(:player_stat, match: match, player: player1, team: team1, goals: 5)
        
        call_result
        
        expect(PlayerStat.where(match: match).count).to eq(2)
        expect(PlayerStat.where(match: match, player: player1).first.goals).to eq(2)
      end
    end

    context 'with empty payload' do
      let(:payload) { [] }

      it 'removes all existing stats' do
        FactoryBot.create(:player_stat, match: match, player: player1, team: team1)
        
        call_result
        
        expect(PlayerStat.where(match: match).count).to eq(0)
      end

      it 'returns empty array' do
        result = call_result
        expect(result).to eq([])
      end
    end

    context 'with multiple teams' do
      let(:player3) { FactoryBot.create(:player) }
      let(:payload) do
        [
          {
            player_id: player1.id,
            team_id: team1.id,
            goals: 3,
            assists: 2,
            own_goals: 0,
            was_goalkeeper: false
          },
          {
            player_id: player2.id,
            team_id: team1.id,
            goals: 1,
            assists: 1,
            own_goals: 0,
            was_goalkeeper: false
          },
          {
            player_id: player3.id,
            team_id: team2.id,
            goals: 2,
            assists: 1,
            own_goals: 0,
            was_goalkeeper: false
          }
        ]
      end

      it 'validates assists per team correctly' do
        # Team1: 4 goals total, 3 assists total (valid: 3 <= 4)
        # Team2: 2 goals total, 1 assist total (valid: 1 <= 2)
        result = call_result
        
        expect(result.length).to eq(3)
        expect(PlayerStat.where(match: match, team: team1).sum(:goals)).to eq(4)
        expect(PlayerStat.where(match: match, team: team1).sum(:assists)).to eq(3)
      end
    end

    context 'with assists on own goals' do
      let(:payload) do
        [
          {
            player_id: player1.id,
            team_id: team1.id,
            goals: 0,
            assists: 1,
            own_goals: 1 # Cannot have assists on own goals
          }
        ]
      end

      it 'raises InvalidAssistsError' do
        expect {
          call_result
        }.to raise_error(PlayerStats::BulkUpsert::InvalidAssistsError)
      end
    end

    context 'when assists exceed goals for a team' do
      let(:payload) do
        [
          {
            player_id: player1.id,
            team_id: team1.id,
            goals: 2,
            assists: 3, # Assists (3) exceed goals (2)
            own_goals: 0,
            was_goalkeeper: false
          }
        ]
      end

      it 'raises InvalidAssistsError' do
        expect {
          call_result
        }.to raise_error(PlayerStats::BulkUpsert::InvalidAssistsError)
      end
    end

    context 'when assists equal goals (boundary case)' do
      let(:payload) do
        [
          {
            player_id: player1.id,
            team_id: team1.id,
            goals: 2,
            assists: 2, # Assists equal goals (valid)
            own_goals: 0,
            was_goalkeeper: false
          }
        ]
      end

      it 'allows the operation' do
        expect {
          call_result
        }.to change(PlayerStat, :count).by(1)
      end
    end

    context 'with string keys in payload' do
      let(:payload) do
        [
          {
            'player_id' => player1.id,
            'team_id' => team1.id,
            'goals' => 2,
            'assists' => 1,
            'own_goals' => 0,
            'was_goalkeeper' => false
          }
        ]
      end

      it 'handles string keys correctly' do
        result = call_result
        
        expect(result.length).to eq(1)
        expect(result.first.player_id).to eq(player1.id)
        expect(result.first.goals).to eq(2)
      end
    end

    context 'with ActionController::Parameters' do
      let(:params_hash) do
        ActionController::Parameters.new(
          player_id: player1.id,
          team_id: team1.id,
          goals: 2,
          assists: 1,
          own_goals: 0,
          was_goalkeeper: false
        ).permit!
      end
      let(:payload) { [params_hash] }

      it 'handles ActionController::Parameters' do
        result = call_result
        
        result_array = result.to_a
        expect(result_array.length).to eq(1)
        expect(result_array.first.player_id).to eq(player1.id)
      end
    end

    context 'transaction rollback on error' do
      let(:payload) do
        [
          {
            player_id: player1.id,
            team_id: team1.id,
            goals: 2,
            assists: 3, # Invalid: assists > goals
            own_goals: 0,
            was_goalkeeper: false
          }
        ]
      end

      it 'rolls back all changes when validation fails' do
        initial_count = PlayerStat.count
        
        expect {
          call_result
        }.to raise_error(PlayerStats::BulkUpsert::InvalidAssistsError)
        
        expect(PlayerStat.count).to eq(initial_count)
        expect(PlayerStat.where(match: match).count).to eq(0)
      end
    end
  end
end
