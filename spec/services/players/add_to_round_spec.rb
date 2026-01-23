# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Players::AddToRound do
  subject(:call_result) do
    described_class.call(player: player, round_id: round.id)
  end

  let(:player) { FactoryBot.create(:player) }
  let(:round) { FactoryBot.create(:round, :with_championship) }

  describe '#call' do
    context 'when player is not in round' do
      it 'adds player to round' do
        expect {
          call_result
        }.to change(PlayerRound, :count).by(1)
        
        expect(player.rounds).to include(round)
      end

      it 'returns the player' do
        expect(call_result).to eq(player)
      end
    end

    context 'when player is already in round' do
      before do
        FactoryBot.create(:player_round, player: player, round: round)
      end

      it 'does not create duplicate association' do
        expect {
          call_result
        }.not_to change(PlayerRound, :count)
        
        expect(player.rounds.count).to eq(1)
      end

      it 'is idempotent' do
        expect(call_result).to eq(player)
        
        # Call again
        result2 = described_class.call(player: player, round_id: round.id)
        expect(result2).to eq(player)
        expect(player.rounds.count).to eq(1)
      end
    end
  end
end
