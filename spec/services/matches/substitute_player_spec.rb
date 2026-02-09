# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Matches::SubstitutePlayer do
  subject(:call_result) do
    described_class.call(
      match: match,
      player_id: player_to_remove.id,
      replacement_player_id: replacement_player.id,
      team_id: team_id
    )
  end

  let(:championship) { FactoryBot.create(:championship) }
  let(:round) { FactoryBot.create(:round, championship: championship) }
  let(:team1) { FactoryBot.create(:team, round: round) }
  let(:team2) { FactoryBot.create(:team, round: round) }
  let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
  let(:player_to_remove) { FactoryBot.create(:player) }
  let(:replacement_player) { FactoryBot.create(:player) }
  let(:team_id) { team1.id }

  before do
    # Add players to round
    round.players << player_to_remove
    round.players << replacement_player

    # Add player_to_remove to team1
    team1.players << player_to_remove
  end

  describe '#call' do
    context 'when all validations pass' do
      it 'removes player from team' do
        expect {
          call_result
        }.to change {
          PlayerTeam.where(player_id: player_to_remove.id, team_id: team1.id).exists?
        }.from(true).to(false)
      end

      it 'adds replacement player to team' do
        expect {
          call_result
        }.to change { team1.players.reload.count }.by(0)
      end

      it 'returns substitution details' do
        result = call_result

        expect(result[:removed_player_id]).to eq(player_to_remove.id)
        expect(result[:removed_player_name]).to eq(player_to_remove.display_name)
        expect(result[:replacement_player_id]).to eq(replacement_player.id)
        expect(result[:replacement_player_name]).to eq(replacement_player.display_name)
        expect(result[:team_id]).to eq(team1.id)
        expect(result[:team_name]).to eq(team1.name)
      end

      it 'does not add replacement if already in team' do
        team1.players << replacement_player

        expect {
          call_result
        }.to change { team1.players.reload.count }.by(-1)
      end
    end

    context 'when team is not part of match' do
      let(:other_team) { FactoryBot.create(:team, round: round) }
      let(:team_id) { other_team.id }

      it 'raises InvalidTeamError' do
        expect {
          call_result
        }.to raise_error(Matches::SubstitutePlayer::InvalidTeamError)
      end
    end

    context 'when player is not in team' do
      before do
        team1.players.delete(player_to_remove)
      end

      it 'raises PlayerNotInTeamError' do
        expect {
          call_result
        }.to raise_error(Matches::SubstitutePlayer::PlayerNotInTeamError)
      end
    end

    context 'when replacement player is not in round' do
      before do
        round.players.delete(replacement_player)
      end

      it 'raises ReplacementNotInRoundError' do
        expect {
          call_result
        }.to raise_error(Matches::SubstitutePlayer::ReplacementNotInRoundError)
      end
    end

    context 'when replacement player is already in match teams' do
      before do
        team2.players << replacement_player
      end

      it 'raises ReplacementInMatchError' do
        expect {
          call_result
        }.to raise_error(Matches::SubstitutePlayer::ReplacementInMatchError)
      end
    end

    context 'when substituting in team2' do
      let(:team_id) { team2.id }

      before do
        team2.players << player_to_remove
        team1.players.delete(player_to_remove)
      end

      it 'removes player from team2' do
        expect {
          call_result
        }.to change { team2.players.reload.count }.by(0)
      end

      it 'adds replacement to team2' do
        expect {
          call_result
        }.to change { team2.players.reload.count }.by(0)
      end
    end
  end
end
