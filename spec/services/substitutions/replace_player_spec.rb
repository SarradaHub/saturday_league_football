# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substitutions::ReplacePlayer do
  subject(:call_result) do
    described_class.call(round: round, player_id: player_to_remove.id, match_id: match_id)
  end

  let(:championship) { FactoryBot.create(:championship) }
  let(:round) { FactoryBot.create(:round, championship: championship) }
  let(:player_to_remove) { FactoryBot.create(:player) }
  let(:replacement_player) { FactoryBot.create(:player) }
  let(:team1) { FactoryBot.create(:team, round: round) }
  let(:team2) { FactoryBot.create(:team, round: round) }
  let(:match_id) { nil }

  before do
    # Add players to round
    round.players << player_to_remove
    round.players << replacement_player

    # Add players to teams
    team1.players << player_to_remove
    team2.players << replacement_player
  end

  describe '#call' do
    context 'when player is in round' do
      it 'removes player from round' do
        expect {
          call_result
        }.to change { round.players.count }.by(-1)
      end

      it 'adds replacement player to round if not already there' do
        # Remove replacement player from round first (rebalance may remove them from team; re-add to team)
        round.player_rounds.find_by(player_id: replacement_player.id)&.destroy
        team2.players << replacement_player unless team2.players.include?(replacement_player)

        expect {
          call_result
        }.to change { round.players.count }.by(0) # -1 removed, +1 added = 0 net change
      end

      it 'returns substitution details' do
        result = call_result

        expect(result[:removed_player_id]).to eq(player_to_remove.id)
        expect(result[:replacement_player_id]).to eq(replacement_player.id)
        expect(result[:replacement_player_name]).to eq(replacement_player.display_name)
      end

      it 'triggers auto-balance via PlayerRound callbacks' do
        expect(RoundTeamGenerator).to receive(:call).at_least(:once)
        call_result
      end
    end

    context 'when player is not in round' do
      let(:player_not_in_round) { FactoryBot.create(:player) }

      subject(:call_result) do
        described_class.call(round: round, player_id: player_not_in_round.id, match_id: match_id)
      end

      it 'raises PlayerNotInRoundError' do
        expect {
          call_result
        }.to raise_error(Substitutions::ReplacePlayer::PlayerNotInRoundError)
      end
    end

    context 'when no available player exists' do
      before do
        # Remove replacement player from round
        round.player_rounds.find_by(player_id: replacement_player.id)&.destroy
        # Make all teams active (playing in matches)
        match = FactoryBot.create(:match, round: round, team_1: team1, team_2: team2)
        allow_any_instance_of(described_class).to receive(:active_match_team_ids).and_return([team1.id, team2.id])
      end

      it 'raises NoAvailablePlayerError' do
        expect {
          call_result
        }.to raise_error(Substitutions::ReplacePlayer::NoAvailablePlayerError)
      end
    end

    context 'when match_id is provided' do
      let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
      let(:match_id) { match.id }
      let(:team3) { FactoryBot.create(:team, round: round) }
      let(:replacement_player) { FactoryBot.create(:player) }

      before do
        team3.players << replacement_player
        # replacement_player already in round via top-level before (round.players << replacement_player)
      end

      it 'excludes teams from active match when finding replacement' do
        result = call_result

        # Should find replacement from team3 (not playing)
        expect(result[:replacement_player_id]).to eq(replacement_player.id)
      end
    end

    context 'when substitution happens between matches' do
      it 'finds replacement from any available team' do
        result = call_result

        expect(result[:replacement_player_id]).to eq(replacement_player.id)
      end
    end
  end
end
