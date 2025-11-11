# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoundTeamGenerator do
  subject(:call_service) { described_class.call(round) }

  let(:championship) { create(:championship, min_players_per_team: 2, max_players_per_team: 4) }
  let(:round) { create(:round, championship:) }

  def create_player_round_without_auto_balance(player:, round:, timestamp: nil)
    allow(RoundTeamGenerator).to receive(:call)
    create(:player_round, player:, round:, created_at: timestamp)
    allow(RoundTeamGenerator).to receive(:call).and_call_original
  end

  def add_players(players, offset: 0)
    players.each_with_index do |player, index|
      create_player_round_without_auto_balance(
        player:,
        round:,
        timestamp: Time.zone.now + (offset + index).minutes
      )
    end
  end

  describe '.call' do
    context 'with four players' do
      let(:players) { create_list(:player, 4) }

      before { add_players(players) }

      it 'creates two teams' do
        expect { call_service }.to change(round.teams, :count).from(0).to(2)
      end

      it 'assigns all players to the first team' do
        call_service
        teams = round.reload.teams.order(:created_at).includes(:players)
        expect(teams.first.players).to match_array(players)
        expect(teams.second.players).to be_empty
      end
    end

    context 'when players change' do
      let(:players) { create_list(:player, 3) }
      let(:extra_player) { create(:player) }

      before do
        add_players(players)
        call_service
        add_players([extra_player], offset: 10)
      end

      it 'keeps the existing team count' do
        expect { call_service }.not_to change(round.teams, :count)
      end

      it 'includes the new player in the round teams' do
        call_service
        round.reload
        expect(round.teams.sum { |team| team.players.count }).to eq(4)
        expect(round.teams.flat_map(&:players)).to include(extra_player)
      end
    end

    context 'when players exceed the maximum per team' do
      let(:players) { create_list(:player, 9) }

      before { add_players(players) }

      it 'creates additional teams' do
        expect { call_service }.to change(round.teams, :count).from(0).to(3)
      end

      it 'spreads players without exceeding the limit' do
        call_service
        ordered_players = round.reload.teams.order(:created_at).map(&:players)
        expect(ordered_players.first).to match_array(players.first(4))
        expect(ordered_players.second).to match_array(players[4, 4])
        expect(ordered_players.third).to contain_exactly(players[8])
      end
    end

    context 'when the minimum per team would be violated' do
      let(:players) { create_list(:player, 6) }

      before do
        championship.update!(min_players_per_team: 5, max_players_per_team: 5)
        add_players(players)
      end

      it 'still creates enough teams to satisfy the maximum' do
        expect { call_service }.to change(round.teams, :count).from(0).to(2)
      end

      it 'keeps the team sizes under the maximum' do
        call_service
        player_counts = round.reload.teams.map { |team| team.players.count }
        expect(player_counts.max).to be <= championship.max_players_per_team
      end
    end
  end
end
