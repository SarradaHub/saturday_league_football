# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/MultipleExpectations

RSpec.describe Rounds::RoundStatistics do
  subject(:call_result) do
    described_class.call(round_id: round.id)
  end

  let(:round) { FactoryBot.create(:round, :with_championship) }
  let(:team1) { FactoryBot.create(:team, round: round) }
  let(:team2) { FactoryBot.create(:team, round: round) }
  let(:match1) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2, winning_team_id: team1.id, draw: false) }
  let(:match2) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2, winning_team_id: nil, draw: true) }
  let(:player1) { FactoryBot.create(:player) }
  let(:player2) { FactoryBot.create(:player) }

  describe '#call' do
    context 'with player stats' do
      before do
        FactoryBot.create(:player_round, player: player1, round: round)
        FactoryBot.create(:player_round, player: player2, round: round)

        FactoryBot.create(:player_stat, player: player1, team: team1, match: match1, goals: 2, assists: 1, own_goals: 0, was_goalkeeper: false)
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match2, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: true)
        FactoryBot.create(:player_stat, player: player2, team: team2, match: match1, goals: 1, assists: 1, own_goals: 0, was_goalkeeper: false)
      end

      it 'aggregates statistics by player' do
        result = call_result

        expect(result).to be_a(Hash)
        # RoundStatistics uses integer keys, not string keys
        expect(result).to have_key(player1.id)
        expect(result).to have_key(player2.id)
      end

      it 'calculates total goals correctly' do
        result = call_result

        player1_stats = result[player1.id]
        expect(player1_stats[:goals]).to eq(3) # 2 + 1
        expect(player1_stats[:assists]).to eq(1)
        expect(player1_stats[:own_goals]).to eq(0)
      end

      it 'counts matches played' do
        result = call_result

        player1_stats = result[player1.id]
        expect(player1_stats[:matches]).to eq(2)
      end

      it 'counts goalkeeper appearances' do
        result = call_result

        player1_stats = result[player1.id]
        expect(player1_stats[:goalkeeper_count]).to eq(1)
      end

      it 'calculates wins, losses, and draws' do
        result = call_result

        player1_stats = result[player1.id]
        # player1 won match1 (team1 won), drew match2
        expect(player1_stats[:wins]).to eq(1)
        expect(player1_stats[:draws]).to eq(1)
      end

      it 'counts player1 losses' do
        result = call_result
        player1_stats = result[player1.id]
        expect(player1_stats[:losses]).to eq(0)
      end

      it 'counts player2 results' do
        result = call_result
        player2_stats = result[player2.id]
        # player2 lost match1 (team2 lost), did not play match2
        expect(player2_stats[:wins]).to eq(0)
        expect(player2_stats[:draws]).to eq(0)
        expect(player2_stats[:losses]).to eq(1)
      end

      it 'includes player information' do
        result = call_result

        player1_stats = result[player1.id]
        expect(player1_stats[:player]).to include(id: player1.id)
      end

      it 'includes player name' do
        result = call_result
        player1_stats = result[player1.id]
        expect(player1_stats[:player]).to include(
          name: player1.display_name
        )
      end
    end

    context 'with no players in round' do
      it 'returns empty hash' do
        result = call_result

        expect(result).to eq({})
      end
    end

    context 'with players but no stats' do
      before do
        FactoryBot.create(:player_round, player: player1, round: round)
      end

      let(:player1_stats) do
        result = call_result
        result[player1.id]
      end

      it 'returns stats with zeros' do
        expect(player1_stats[:goals]).to eq(0)
        expect(player1_stats[:assists]).to eq(0)
      end

      it 'returns zero matches and results' do
        expect(player1_stats[:matches]).to eq(0)
        expect(player1_stats[:wins]).to eq(0)
        expect(player1_stats[:losses]).to eq(0)
        expect(player1_stats[:draws]).to eq(0)
      end
    end

    context 'with multiple matches and complex scenarios' do
      before do
        FactoryBot.create(:player_round, player: player1, round: round)

        # player1: win, draw, loss
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match1, goals: 1)
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match2, goals: 1)
        match3 = FactoryBot.create(:match, round: round, team_1: team1, team_2: team2, winning_team_id: team2.id, draw: false)
        FactoryBot.create(:player_stat, player: player1, team: team1, match: match3, goals: 1)
      end

      let(:player1_stats) { call_result[player1.id] }

      it 'calculates win/draw/loss counts' do
        expect(player1_stats[:wins]).to eq(1)
        expect(player1_stats[:draws]).to eq(1)
        expect(player1_stats[:losses]).to eq(1)
      end

      it 'counts matches played' do
        expect(player1_stats[:matches]).to eq(3)
      end
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/MultipleExpectations
