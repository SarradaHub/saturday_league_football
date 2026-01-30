# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Players::AddToTeam do
  subject(:call_result) do
    described_class.call(player: player, team_id: team.id)
  end

  let(:player) { FactoryBot.create(:player) }
  let(:team) { FactoryBot.create(:team, :with_round) }

  describe '#call' do
    context 'when player is not in team' do
      it 'adds player to team' do
        expect {
          call_result
        }.to change(PlayerTeam, :count).by(1)

        expect(player.teams).to include(team)
      end

      it 'returns the player' do
        expect(call_result).to eq(player)
      end
    end

    context 'when player is already in team' do
      before do
        FactoryBot.create(:player_team, player: player, team: team)
      end

      it 'does not create duplicate association' do
        expect {
          call_result
        }.not_to change(PlayerTeam, :count)

        expect(player.teams.count).to eq(1)
      end

      it 'is idempotent' do
        expect(call_result).to eq(player)

        # Call again
        result2 = described_class.call(player: player, team_id: team.id)
        expect(result2).to eq(player)
        expect(player.teams.count).to eq(1)
      end
    end
  end
end
