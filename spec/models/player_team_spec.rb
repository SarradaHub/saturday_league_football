# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerTeam, type: :model do
  subject { FactoryBot.build(:player_team, player:, team:) }

  let(:championship) { FactoryBot.create(:championship, min_players_per_team: 1, max_players_per_team: 2) }
  let(:round) { FactoryBot.create(:round, championship:) }
  let(:team) { FactoryBot.create(:team, round:) }
  let(:player) { FactoryBot.create(:player) }


  it { is_expected.to belong_to :player }
  it { is_expected.to belong_to :team }
  it { is_expected.to be_valid }

  describe 'limits' do
    it 'prevents adding a player when the team reached the maximum' do
      FactoryBot.create(:player_team, player: FactoryBot.create(:player), team:)
      FactoryBot.create(:player_team, player: FactoryBot.create(:player), team:)

      extra = described_class.create(player: FactoryBot.create(:player), team:)

      expect(extra).not_to be_persisted
      expect(extra.errors[:team]).to include('has already reached the maximum of 2 players')
    end

    it 'prevents removing a player when it would drop below the minimum' do
      team_membership = described_class.create!(player:, team:)

      expect(team_membership.destroy).to be_falsey
      expect(team_membership.errors[:team]).to include(I18n.t('errors.messages.greater_than_or_equal_to', count: championship.min_players_per_team))
    end
  end
end
