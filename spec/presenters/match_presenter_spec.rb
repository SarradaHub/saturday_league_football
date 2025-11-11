# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchPresenter do
  subject(:presenter) { described_class.new(match) }

  let(:team_1) { FactoryBot.create(:team) }
  let(:team_2) { FactoryBot.create(:team) }
  let(:round) { FactoryBot.create(:round, :with_championship) }
  let(:match) { FactoryBot.create(:match, round: round, team_1: team_1, team_2: team_2, draw: false) }

  let(:team_1_player) { FactoryBot.create(:player) }
  let(:team_2_player) { FactoryBot.create(:player) }

  before do
    team_1.players << team_1_player
    team_2.players << team_2_player

    FactoryBot.create(:player_stat, player: team_1_player, team: team_1, match: match, goals: 2, assists: 1, own_goals: 0)
    FactoryBot.create(:player_stat, player: team_2_player, team: team_2, match: match, goals: 1, assists: 0, own_goals: 1)
  end


  describe '#team_1_goals' do
    it 'sums goals and opponent own goals' do
      expect(presenter.team_1_goals).to eq(3)
    end
  end

  describe '#team_2_goals' do
    it 'sums goals and opponent own goals' do
      expect(presenter.team_2_goals).to eq(1)
    end
  end

  describe '#statistics' do
    it 'returns structured breakdown for each team' do
      stats = presenter.as_json[:statistics]

      expect(stats[:team_1][:goal_scorers]).to include(team_1_player.name => 2)
      expect(stats[:team_2][:own_goals]).to include(team_2_player.name => 1)
      expect(stats[:scoreboard]).to eq({ team_1: 3, team_2: 1 })
    end
  end
end
