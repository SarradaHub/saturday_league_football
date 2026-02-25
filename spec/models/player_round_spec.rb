# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerRound, type: :model do
  describe 'callbacks' do
    let(:round) { create(:round, :with_championship) }
    let(:player) { create(:player) }

    it 'triggers RoundTeamGenerator when round has no finalized matches' do
      allow(Rounds::RoundTeamGenerator).to receive(:call)
      allow(Rounds::AddPlayerToLastActiveTeam).to receive(:call)

      described_class.create!(player:, round:)

      expect(Rounds::RoundTeamGenerator).to have_received(:call).with(round)
      expect(Rounds::AddPlayerToLastActiveTeam).not_to have_received(:call)
    end

    it 'triggers AddPlayerToLastActiveTeam when round has finalized matches' do
      team1 = create(:team, round:, name: 'Time 1')
      team2 = create(:team, round:, name: 'Time 2')
      create(:match, round:, team_1: team1, team_2: team2, draw: true)

      allow(Rounds::RoundTeamGenerator).to receive(:call)
      allow(Rounds::AddPlayerToLastActiveTeam).to receive(:call)

      described_class.create!(player:, round:)

      expect(Rounds::AddPlayerToLastActiveTeam).to have_received(:call).with(round: round, player: player)
      expect(Rounds::RoundTeamGenerator).not_to have_received(:call)
    end

    it 'triggers RoundTeamGenerator on destroy' do
      allow(Rounds::RoundTeamGenerator).to receive(:call)
      allow(Rounds::AddPlayerToLastActiveTeam).to receive(:call)

      player_round = described_class.create!(player:, round:)

      player_round.destroy!

      expect(Rounds::RoundTeamGenerator).to have_received(:call).with(round).at_least(:once)
    end

    it 'skips balancing for goalkeeper_only' do
      allow(Rounds::RoundTeamGenerator).to receive(:call)
      allow(Rounds::AddPlayerToLastActiveTeam).to receive(:call)

      described_class.create!(player:, round:, goalkeeper_only: true)

      expect(Rounds::RoundTeamGenerator).not_to have_received(:call)
      expect(Rounds::AddPlayerToLastActiveTeam).not_to have_received(:call)
    end
  end
end
