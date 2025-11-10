# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoundTeamGenerator do
  let(:championship) { create(:championship, min_players_per_team: 2, max_players_per_team: 4) }
  let(:round) { create(:round, championship:) }

  describe '.call' do
    it 'creates default teams and distributes players by order' do
      players = create_list(:player, 4)

      players.each_with_index do |player, index|
        create(:player_round, player:, round:, created_at: Time.zone.now + index.minutes)
      end

      expect { described_class.call(round) }.to change { round.teams.count }.from(0).to(2)

      round.reload
      teams = round.teams.order(:created_at).includes(:players).to_a

      expect(teams.size).to eq(2)
      expect(teams.first.players).to contain_exactly(players[0], players[2])
      expect(teams.second.players).to contain_exactly(players[1], players[3])
    end

    it 'rebalances teams when players change' do
      players = create_list(:player, 3)
      players.each_with_index do |player, index|
        create(:player_round, player:, round:, created_at: Time.zone.now + index.minutes)
      end

      described_class.call(round)
      round.reload

      extra_player = create(:player)
      create(:player_round, player: extra_player, round:, created_at: Time.zone.now + 10.minutes)

      expect { described_class.call(round) }.not_to change { round.teams.count }

      round.reload
      expect(round.teams.sum { |team| team.players.count }).to eq(4)
      expect(round.teams.flat_map(&:players)).to include(extra_player)
    end

    it 'adds extra teams to respect the maximum player limit' do
      players = create_list(:player, 9)
      players.each { |player| create(:player_round, player:, round:) }

      expect { described_class.call(round) }.to change { round.teams.count }.from(0).to(3)

      round.reload
      expect(round.teams.map { |team| team.players.count }.max).to be <= championship.max_players_per_team
    end

    it 'reduces the team usage when players cannot satisfy the minimum' do
      championship.update!(min_players_per_team: 4, max_players_per_team: 10)
      players = create_list(:player, 5)
      players.each { |player| create(:player_round, player:, round:) }

      described_class.call(round)
      round.reload

      active_teams = round.teams.order(:created_at).limit(1)
      expect(active_teams.size).to eq(1)
      expect(active_teams.first.players.count).to eq(5)
    end
  end
end

