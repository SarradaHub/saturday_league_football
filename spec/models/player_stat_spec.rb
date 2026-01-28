# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerStat, type: :model do
  subject { FactoryBot.create(:player_stat, :with_player, :with_team, :with_match) }

  it { should belong_to :player }
  it { should belong_to :team }
  it { should belong_to :match }
  it { should validate_presence_of :goals }
  it { should validate_presence_of :assists }
  it { should validate_presence_of :own_goals }
  it { should be_valid }
<<<<<<< HEAD

  describe 'assists rules' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: FactoryBot.create(:team, round: round)) }
    let(:p1) { FactoryBot.create(:player) }
    let(:p2) { FactoryBot.create(:player) }

    before do
      team.players << p1 << p2
    end

    it 'invalid when team total assists > team total goals' do
      FactoryBot.create(:player_stat, player: p1, team: team, match: match, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false)
      stat2 = FactoryBot.build(:player_stat, player: p2, team: team, match: match, goals: 0, assists: 2, own_goals: 0, was_goalkeeper: false)
      expect(stat2).not_to be_valid
      expect(stat2.errors[:assists]).to include(I18n.t('activerecord.errors.models.player_stat.attributes.assists.assists_require_goals'))
    end

    it 'invalid when player has own_goals > 0 and assists > 0' do
      stat = FactoryBot.build(:player_stat, player: p1, team: team, match: match, goals: 0, assists: 1, own_goals: 1, was_goalkeeper: false)
      expect(stat).not_to be_valid
      expect(stat.errors[:assists]).to include(I18n.t('activerecord.errors.models.player_stat.attributes.assists.no_assists_on_own_goals'))
    end

    it 'valid when assists <= goals and no assist on own-goal scorer' do
      FactoryBot.create(:player_stat, player: p1, team: team, match: match, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false)
      stat2 = FactoryBot.build(:player_stat, player: p2, team: team, match: match, goals: 0, assists: 1, own_goals: 0, was_goalkeeper: false)
      expect(stat2).to be_valid
    end
  end
=======
>>>>>>> main
end
