# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rounds::AddPlayerToLastActiveTeam do
  let(:championship) { create(:championship, min_players_per_team: 2, max_players_per_team: 4) }
  let(:round) { create(:round, championship:) }

  def create_player_round_without_auto_balance(player:, round:)
    allow(Rounds::RoundTeamGenerator).to receive(:call)
    allow(Rounds::AddPlayerToLastActiveTeam).to receive(:call)
    create(:player_round, player:, round:)
    allow(Rounds::RoundTeamGenerator).to receive(:call).and_call_original
    allow(Rounds::AddPlayerToLastActiveTeam).to receive(:call).and_call_original
  end

  describe '.call' do
    context 'when last active team has capacity' do
      it 'adds player to the last active team by created_at' do
        team1 = create(:team, round:, name: 'Time 1')
        team2 = create(:team, round:, name: 'Time 2')
        team2.update_column(:created_at, team1.created_at + 1.minute)

        players = create_list(:player, 3)
        create_player_round_without_auto_balance(player: players[0], round:)
        create_player_round_without_auto_balance(player: players[1], round:)
        create_player_round_without_auto_balance(player: players[2], round:)

        Rounds::RoundTeamGenerator.call(round)
        create(:match, round:, team_1: team1, team_2: team2, draw: true)

        new_player = create(:player)
        create_player_round_without_auto_balance(player: new_player, round:)

        result = described_class.call(round: round.reload, player: new_player)

        expect(result).to eq(team2)
        expect(team2.reload.players).to include(new_player)
      end

      it 'ignores blocked teams' do
        team1 = create(:team, round:, name: 'Time 1', is_blocked: false)
        team2 = create(:team, round:, name: 'Time 2', is_blocked: true)
        team2.update_column(:created_at, team1.created_at + 1.minute)

        players = create_list(:player, 2)
        create_player_round_without_auto_balance(player: players[0], round:)
        create_player_round_without_auto_balance(player: players[1], round:)
        Rounds::RoundTeamGenerator.call(round)
        create(:match, round:, team_1: team1, team_2: team2, draw: true)

        new_player = create(:player)
        create_player_round_without_auto_balance(player: new_player, round:)

        result = described_class.call(round: round.reload, player: new_player)

        expect(result).to eq(team1)
        expect(team1.reload.players).to include(new_player)
      end
    end

    context 'when all active teams are full' do
      it 'creates a new team and adds the player' do
        players = create_list(:player, 6)
        players.each { |p| create_player_round_without_auto_balance(player: p, round:) }
        Rounds::RoundTeamGenerator.call(round)
        team1, team2 = round.teams.order(:created_at).to_a
        create(:match, round:, team_1: team1, team_2: team2, draw: true)

        new_player = create(:player)
        create_player_round_without_auto_balance(player: new_player, round:)

        expect { described_class.call(round: round.reload, player: new_player) }
          .to change(round.teams, :count).by(1)

        new_team = round.teams.order(created_at: :desc).first
        expect(new_team.players).to contain_exactly(new_player)
      end
    end

    context 'when using the most recent team among multiple active ones' do
      it 'selects the team with highest created_at when multiple have capacity' do
        team1 = create(:team, round:, name: 'Time 1')
        team2 = create(:team, round:, name: 'Time 2')
        team3 = create(:team, round:, name: 'Time 3')
        team2.update_column(:created_at, team1.created_at + 30.seconds)
        team3.update_column(:created_at, team1.created_at + 1.minute)

        players = create_list(:player, 3)
        players.each { |p| create_player_round_without_auto_balance(player: p, round:) }
        Rounds::RoundTeamGenerator.call(round)
        create(:match, round:, team_1: team1, team_2: team2, draw: true)

        new_player = create(:player)
        create_player_round_without_auto_balance(player: new_player, round:)

        result = described_class.call(round: round.reload, player: new_player)

        expect(result).to eq(team3)
        expect(team3.reload.players).to include(new_player)
      end
    end

    context 'when round or player is blank' do
      it 'returns nil when round is blank' do
        player = create(:player)
        expect(described_class.call(round: nil, player:)).to be_nil
      end

      it 'returns nil when player is blank' do
        expect(described_class.call(round:, player: nil)).to be_nil
      end
    end
  end
end
