# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChampionshipPresenter do
  subject(:presenter) { described_class.new(championship) }

  let(:championship) { FactoryBot.create(:championship) }

  describe 'delegates' do
    it 'delegates id to resource' do
      expect(presenter.id).to eq(championship.id)
    end

    it 'delegates name to resource' do
      expect(presenter.name).to eq(championship.name)
    end

    it 'delegates description to resource' do
      expect(presenter.description).to eq(championship.description)
    end

    it 'delegates created_at to resource' do
      expect(presenter.created_at).to eq(championship.created_at)
    end

    it 'delegates updated_at to resource' do
      expect(presenter.updated_at).to eq(championship.updated_at)
    end
  end

  describe '#as_json' do
    let(:round1) { FactoryBot.create(:round, championship: championship, round_date: Date.new(2025, 1, 1)) }
    let(:round2) { FactoryBot.create(:round, championship: championship, round_date: Date.new(2025, 1, 15)) }
    let(:player1) { FactoryBot.create(:player) }
    let(:player2) { FactoryBot.create(:player) }
    let(:json) { presenter.as_json(include_rounds: true, include_players: true) }

    before do
      FactoryBot.create(:player_round, player: player1, round: round1)
      FactoryBot.create(:player_round, player: player2, round: round2)
    end

    it 'returns a hash with identifiers' do
      expect(json).to be_a(Hash)
      expect(json[:id]).to eq(championship.id)
    end

    it 'includes name and description' do
      expect(json[:name]).to eq(championship.name)
      expect(json[:description]).to eq(championship.description)
    end

    it 'returns totals' do
      expect(json[:total_players]).to eq(2)
      expect(json[:round_total]).to eq(2)
    end

    it 'returns timestamps' do
      expect(json[:created_at]).to eq(championship.created_at)
      expect(json[:updated_at]).to eq(championship.updated_at)
    end

    it 'includes rounds and players arrays' do
      expect(json[:rounds]).to be_an(Array)
      expect(json[:players]).to be_an(Array)
    end

    it 'includes serialized rounds' do
      expect(json[:rounds].length).to eq(2)
      expect(json[:rounds].first[:id]).to be_in([round1.id, round2.id])
    end

    it 'includes serialized players' do
      expect(json[:players].length).to eq(2)
      expect(json[:players].map { |p| p[:id] }).to contain_exactly(player1.id, player2.id)
    end
  end

  describe '#round_total' do
    context 'with rounds' do
      before do
        FactoryBot.create(:round, championship: championship)
        FactoryBot.create(:round, championship: championship)
        FactoryBot.create(:round, championship: championship)
      end

      it 'returns the count of rounds' do
        expect(presenter.round_total).to eq(3)
      end
    end

    context 'without rounds' do
      it 'returns zero' do
        expect(presenter.round_total).to eq(0)
      end
    end
  end

  describe '#total_players' do
    context 'with players' do
      let(:round1) { FactoryBot.create(:round, championship: championship) }
      let(:round2) { FactoryBot.create(:round, championship: championship) }
      let(:player1) { FactoryBot.create(:player) }
      let(:player2) { FactoryBot.create(:player) }
      let(:player3) { FactoryBot.create(:player) }

      before do
        FactoryBot.create(:player_round, player: player1, round: round1)
        FactoryBot.create(:player_round, player: player2, round: round1)
        FactoryBot.create(:player_round, player: player3, round: round2)
        # Add player1 to round2 as well (should still count as 1 distinct player)
        FactoryBot.create(:player_round, player: player1, round: round2)
      end

      it 'returns distinct count of players' do
        expect(presenter.total_players).to eq(3)
      end

      it 'memoizes the result' do
        first_call = presenter.total_players
        second_call = presenter.total_players
        expect(first_call).to eq(second_call)
      end
    end

    context 'without players' do
      it 'returns zero' do
        expect(presenter.total_players).to eq(0)
      end
    end
  end

  describe '#rounds' do
    let(:round1) { FactoryBot.create(:round, championship: championship, round_date: Date.new(2025, 1, 15)) }
    let(:round2) { FactoryBot.create(:round, championship: championship, round_date: Date.new(2025, 1, 1)) }
    let(:round3) { FactoryBot.create(:round, championship: championship, round_date: Date.new(2025, 1, 10)) }
    let(:expected_round_dates) do
      [Date.new(2025, 1, 1), Date.new(2025, 1, 10), Date.new(2025, 1, 15)]
    end

    before do
      round1
      round2
      round3
    end

    it 'returns rounds ordered by round_date ascending' do
      rounds = presenter.rounds.to_a
      expect(rounds.map(&:round_date)).to eq(expected_round_dates)
    end
  end

  describe '#players' do
    let(:round1) { FactoryBot.create(:round, championship: championship) }
    let(:round2) { FactoryBot.create(:round, championship: championship) }
    let(:player1) { FactoryBot.create(:player) }
    let(:player2) { FactoryBot.create(:player) }

    before do
      FactoryBot.create(:player_round, player: player1, round: round1)
      FactoryBot.create(:player_round, player: player2, round: round2)
      # Add player1 to round2 as well
      FactoryBot.create(:player_round, player: player1, round: round2)
    end

    it 'returns distinct players' do
      players = presenter.players.to_a
      expect(players.length).to eq(2)
      expect(players.map(&:id)).to contain_exactly(player1.id, player2.id)
    end
  end

  describe '#serialized_rounds' do
    let!(:round) { FactoryBot.create(:round, championship: championship) }
    let(:serialized) { presenter.send(:serialized_rounds) }

    it 'serializes rounds using RoundSerializer' do
      expect(serialized).to be_an(Array)
    end

    it 'returns one round' do
      expect(serialized.length).to eq(1)
    end

    it 'includes round fields' do
      expect(serialized.first).to be_a(Hash)
      expect(serialized.first[:id]).to eq(round.id)
      expect(serialized.first[:name]).to eq(round.name)
    end
  end

  describe '#serialized_players' do
    let(:round) { FactoryBot.create(:round, championship: championship) }
    let(:player) { FactoryBot.create(:player) }
    let(:serialized) { presenter.send(:serialized_players) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
    end

    it 'serializes players using PlayerPresenter' do
      expect(serialized).to be_an(Array)
    end

    it 'includes player fields' do
      expect(serialized.first).to be_a(Hash)
      expect(serialized.first[:id]).to eq(player.id)
      expect(serialized.first[:display_name]).to eq(player.display_name)
    end
  end

  context 'with empty championship' do
    let(:json) { presenter.as_json(include_rounds: true, include_players: true) }

    it 'returns zero totals' do
      expect(json[:round_total]).to eq(0)
      expect(json[:total_players]).to eq(0)
    end

    it 'returns empty collections' do
      expect(json[:rounds]).to eq([])
      expect(json[:players]).to eq([])
    end
  end

  context 'with rounds but no players' do
    before do
      FactoryBot.create(:round, championship: championship)
      FactoryBot.create(:round, championship: championship)
    end

    let(:json) { presenter.as_json(include_rounds: true, include_players: true) }

    it 'returns round and player totals' do
      expect(json[:round_total]).to eq(2)
      expect(json[:total_players]).to eq(0)
    end

    it 'returns rounds collection' do
      expect(json[:rounds]).to be_an(Array)
      expect(json[:rounds].length).to eq(2)
    end

    it 'returns empty players collection' do
      expect(json[:players]).to eq([])
    end
  end

  context 'with one round and one player' do
    let!(:round) { FactoryBot.create(:round, championship: championship) }
    let!(:player) { FactoryBot.create(:player) }
    let(:json) { presenter.as_json(include_rounds: true, include_players: true) }

    before do
      FactoryBot.create(:player_round, player: player, round: round)
    end

    it 'returns totals for single-element collections' do
      expect(json[:round_total]).to eq(1)
      expect(json[:total_players]).to eq(1)
    end

    it 'returns single round and player' do
      expect(json[:rounds].length).to eq(1)
      expect(json[:players].length).to eq(1)
    end

    it 'returns round and player ids' do
      expect(json[:rounds].first[:id]).to eq(round.id)
      expect(json[:players].first[:id]).to eq(player.id)
    end
  end
end
