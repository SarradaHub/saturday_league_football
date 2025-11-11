# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerRound, type: :model do
  describe 'callbacks' do
    let(:round) { create(:round, :with_championship) }
    let(:player) { create(:player) }

    it 'triggers team balancing after creation' do
      allow(RoundTeamGenerator).to receive(:call)

      described_class.create!(player:, round:)

      expect(RoundTeamGenerator).to have_received(:call).with(round)
    end

    it 'triggers team balancing after destroy' do
      player_round = described_class.create!(player:, round:)
      allow(RoundTeamGenerator).to receive(:call)

      player_round.destroy!

      expect(RoundTeamGenerator).to have_received(:call).with(round)
    end
  end
end
