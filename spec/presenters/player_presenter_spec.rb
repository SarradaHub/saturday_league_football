# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerPresenter do
  subject(:presenter) { described_class.new(player) }

  let(:player) { FactoryBot.create(:player, name: 'John Doe') }

  describe 'delegates' do
    it 'delegates id to resource' do
      expect(presenter.id).to eq(player.id)
    end

    it 'delegates name to resource' do
      expect(presenter.name).to eq('John Doe')
    end

    it 'delegates created_at to resource' do
      expect(presenter.created_at).to eq(player.created_at)
    end

    it 'delegates updated_at to resource' do
      expect(presenter.updated_at).to eq(player.updated_at)
    end
  end

  describe '#as_json' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team) { FactoryBot.create(:team, round: round) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
      team.players << player
    end

    it 'returns complete json structure' do
      json = presenter.as_json

      expect(json).to be_a(Hash)
      expect(json[:id]).to eq(player.id)
      expect(json[:name]).to eq('John Doe')
      expect(json[:rounds]).to be_an(Array)
      expect(json[:total_goals]).to be_a(Integer)
      expect(json[:total_assists]).to be_a(Integer)
      expect(json[:total_own_goals]).to be_a(Integer)
      expect(json[:total_matches]).to be_a(Integer)
      expect(json[:player_stats]).to be_an(Array)
      expect(json[:created_at]).to eq(player.created_at)
      expect(json[:updated_at]).to eq(player.updated_at)
    end

    it 'includes serialized rounds' do
      json = presenter.as_json

      expect(json[:rounds].length).to eq(1)
      expect(json[:rounds].first).to be_a(Hash)
      expect(json[:rounds].first[:id]).to eq(round.id)
    end

    it 'includes serialized player_stats' do
      round = FactoryBot.create(:round, :with_championship)
      team = FactoryBot.create(:team, round: round)
      team2 = FactoryBot.create(:team, round: round)
      match = FactoryBot.create(:match, round: round, team_1: team, team_2: team2)
      player_stat = FactoryBot.create(:player_stat, player: player, team: team, match: match)
      json = presenter.as_json

      expect(json[:player_stats].length).to eq(1)
      expect(json[:player_stats].first).to be_a(Hash)
      expect(json[:player_stats].first[:id]).to eq(player_stat.id)
    end
  end

  describe '#rounds' do
    let(:round1) { FactoryBot.create(:round, :with_championship) }
    let(:round2) { FactoryBot.create(:round, :with_championship) }

    before do
      FactoryBot.create(:player_round, player: player, round: round1)
      FactoryBot.create(:player_round, player: player, round: round2)
    end

    it 'returns rounds associated with the player' do
      rounds = presenter.rounds.to_a

      expect(rounds.length).to eq(2)
      expect(rounds.map(&:id)).to contain_exactly(round1.id, round2.id)
    end
  end

  describe '#player_stats' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: team2) }

    before do
      FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 2, assists: 0, own_goals: 0)
      FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 1, assists: 1, own_goals: 0)
    end

    it 'returns player_stats associated with the player' do
      stats = presenter.player_stats.to_a

      expect(stats.length).to eq(2)
    end
  end

  describe '#total_goals' do
    context 'with stats' do
      let(:round) { FactoryBot.create(:round, :with_championship) }
      let(:team) { FactoryBot.create(:team, round: round) }
      let(:team2) { FactoryBot.create(:team, round: round) }
      let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: team2) }

      before do
        FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 2)
        FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 3)
      end

      it 'sums goals from all player_stats' do
        expect(presenter.total_goals).to eq(5)
      end

      it 'memoizes the result' do
        first_call = presenter.total_goals
        second_call = presenter.total_goals
        expect(first_call).to eq(second_call)
        expect(presenter.instance_variable_get(:@total_goals)).to eq(5)
      end
    end

    context 'without stats' do
      it 'returns zero' do
        expect(presenter.total_goals).to eq(0)
      end
    end
  end

  describe '#total_assists' do
    context 'with stats' do
      let(:round) { FactoryBot.create(:round, :with_championship) }
      let(:team) { FactoryBot.create(:team, round: round) }
      let(:team2) { FactoryBot.create(:team, round: round) }
      let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: team2) }

      before do
        FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 2, assists: 1, own_goals: 0)
        FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 3, assists: 2, own_goals: 0)
      end

      it 'sums assists from all player_stats' do
        expect(presenter.total_assists).to eq(3)
      end

      it 'memoizes the result' do
        first_call = presenter.total_assists
        second_call = presenter.total_assists
        expect(first_call).to eq(second_call)
        expect(presenter.instance_variable_get(:@total_assists)).to eq(3)
      end
    end

    context 'without stats' do
      it 'returns zero' do
        expect(presenter.total_assists).to eq(0)
      end
    end
  end

  describe '#total_own_goals' do
    context 'with stats' do
      let(:round) { FactoryBot.create(:round, :with_championship) }
      let(:team) { FactoryBot.create(:team, round: round) }
      let(:team2) { FactoryBot.create(:team, round: round) }
      let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: team2) }

      before do
        FactoryBot.create(:player_stat, player: player, team: team, match: match, own_goals: 1)
        FactoryBot.create(:player_stat, player: player, team: team, match: match, own_goals: 1)
      end

      it 'sums own_goals from all player_stats' do
        expect(presenter.total_own_goals).to eq(2)
      end

      it 'memoizes the result' do
        first_call = presenter.total_own_goals
        second_call = presenter.total_own_goals
        expect(first_call).to eq(second_call)
        expect(presenter.instance_variable_get(:@total_own_goals)).to eq(2)
      end
    end

    context 'without stats' do
      it 'returns zero' do
        expect(presenter.total_own_goals).to eq(0)
      end
    end
  end

  describe '#total_matches' do
    context 'when player has teams' do
      let(:round) { FactoryBot.create(:round, :with_championship) }
      let(:team1) { FactoryBot.create(:team, round: round) }
      let(:team2) { FactoryBot.create(:team, round: round) }
      let(:match1) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
      let(:match2) { FactoryBot.create(:match, round: round, team_1: team2, team_2: team1) }
      let(:match3) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }

      before do
        team1.players << player
        match1
        match2
        match3
      end

      it 'returns count of matches where player teams participated' do
        # player is in team1, which is in match1, match2, match3
        # But match2 has team1 as team_2, so it should be counted
        expect(presenter.total_matches).to eq(3)
      end
    end

    context 'when team_ids is empty' do
      it 'returns zero' do
        expect(presenter.total_matches).to eq(0)
      end
    end

    context 'when player has teams but no matches' do
      let(:round) { FactoryBot.create(:round, :with_championship) }
      let(:team) { FactoryBot.create(:team, round: round) }

      before do
        team.players << player
      end

      it 'returns zero' do
        expect(presenter.total_matches).to eq(0)
      end
    end
  end

  describe '#serialized_rounds' do
    let(:round) { FactoryBot.create(:round, :with_championship) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
    end

    it 'serializes rounds using RoundSerializer' do
      serialized = presenter.send(:serialized_rounds)
      expect(serialized).to be_an(Array)
      expect(serialized.first).to be_a(Hash)
      expect(serialized.first[:id]).to eq(round.id)
      expect(serialized.first[:name]).to eq(round.name)
    end
  end

  describe '#serialized_stats' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: team2) }
    let!(:player_stat) { FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 1, assists: 0, own_goals: 0) }

    it 'serializes player_stats using PlayerStatSerializer' do
      serialized = presenter.send(:serialized_stats)
      expect(serialized).to be_an(Array)
      expect(serialized.length).to eq(1)
      expect(serialized.first).to be_a(Hash)
      expect(serialized.first[:id]).to eq(player_stat.id)
      expect(serialized.first[:goals]).to eq(player_stat.goals)
    end
  end

  context 'with player without stats' do
    it 'handles player without stats' do
      json = presenter.as_json
      expect(json[:total_goals]).to eq(0)
      expect(json[:total_assists]).to eq(0)
      expect(json[:total_own_goals]).to eq(0)
      expect(json[:player_stats]).to eq([])
    end
  end

  context 'with player without teams' do
    it 'handles player without teams' do
      json = presenter.as_json
      expect(json[:total_matches]).to eq(0)
    end
  end

  context 'with player without rounds' do
    it 'handles player without rounds' do
      json = presenter.as_json
      expect(json[:rounds]).to eq([])
    end
  end
end
