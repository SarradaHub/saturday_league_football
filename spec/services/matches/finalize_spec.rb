# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Matches::Finalize do
  subject(:call_result) do
    described_class.call(match: match)
  end

  let(:round) { FactoryBot.create(:round, :with_championship) }
  let(:team1) { FactoryBot.create(:team, round: round) }
  let(:team2) { FactoryBot.create(:team, round: round) }
  let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
  let(:player1) { FactoryBot.create(:player) }
  let(:player2) { FactoryBot.create(:player) }

  describe '#call' do
    context 'when team1 wins' do
      before do
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match, goals: 3, assists: 1, own_goals: 0)
        FactoryBot.create(:player_stat, player: player2, team: team2, match: match, goals: 1, assists: 0, own_goals: 0)
      end

      it 'calculates goals correctly' do
        result = call_result

        expect(result).to eq(match)
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

      it 'sets team2 as winner' do
        call_result
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
        call_result
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

      it 'includes own goals in team1 score' do
        call_result
        match.reload

        # team1 should have 2 goals (1 goal + 1 own goal from team2)
        # team2 should have 0 goals (0 goals + 0 own goals from team1)
        expect(match.winning_team_id).to eq(team1.id)
        expect(match.draw).to be false
      end
    end

    context 'with multiple players scoring' do
      let(:extra_players) { FactoryBot.create_list(:player, 2) }

      before do
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match, goals: 2, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: extra_players.first, team: team1, match: match, goals: 1, assists: 1, own_goals: 0)
        FactoryBot.create(:player_stat, player: player2, team: team2, match: match, goals: 1, assists: 0, own_goals: 0)
        FactoryBot.create(:player_stat, player: extra_players.last, team: team2, match: match, goals: 0, assists: 0, own_goals: 1)
      end

      it 'sums all goals correctly' do
        call_result
        match.reload

        # team1: 2 + 1 = 3 goals, team2: 1 + 0 = 1 goal (plus 1 own goal for team1 = 2 total for team1)
        # Actually: team1 gets own goals from team2, so team1 = 3 + 1 = 4, team2 = 1
        expect(match.winning_team_id).to eq(team1.id)
      end
    end

    context 'when team is blank' do
      before do
        FactoryBot.create(:player_stat, player: player2, team: team2, match: match, goals: 1, assists: 0, own_goals: 0)
      end

      it 'handles blank team gracefully' do
        # Match model requires team_1/team_2; stub team_1 as nil to exercise calculate_goals_for(team.blank?) branch
        allow(match).to receive_messages(team_1: nil, team_1_id: nil)

        call_result
        match.reload

        # team_1 treated as blank => 0 goals; team_2 has 1 => team_2 wins
        expect(match.winning_team_id).to eq(team2.id)
        expect(match.draw).to be false
      end
    end

    context 'when no goals are scored' do
      it 'marks as draw' do
        call_result
        match.reload

        expect(match.winning_team_id).to be_nil
        expect(match.draw).to be true
      end
    end
  end
end
