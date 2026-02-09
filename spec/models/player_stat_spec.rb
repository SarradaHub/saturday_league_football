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

  describe 'goalkeeper rules' do
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:team3) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:match2) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team3) }
    let(:player) { FactoryBot.create(:player) }

    before do
      team1.players << player
      team2.players << player
      team3.players << player
    end

    it 'invalid when player is both goalkeeper and line player in same match' do
      FactoryBot.create(:player_stat, player: player, team: team1, match: match, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false)
      stat2 = FactoryBot.build(:player_stat, player: player, team: team2, match: match, goals: 0, assists: 0, own_goals: 0, was_goalkeeper: true)
      expect(stat2).not_to be_valid
      expect(stat2.errors[:was_goalkeeper]).to include(I18n.t('activerecord.errors.models.player_stat.attributes.was_goalkeeper.goalkeeper_not_line_player'))
    end

    it 'valid when goalkeeper is line player in different match' do
      FactoryBot.create(:player_stat, player: player, team: team1, match: match, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false)
      stat2 = FactoryBot.build(:player_stat, player: player, team: team3, match: match2, goals: 0, assists: 0, own_goals: 0, was_goalkeeper: true)
      expect(stat2).to be_valid
    end

    it 'valid when player is only goalkeeper (no line player stats)' do
      stat = FactoryBot.build(:player_stat, player: player, team: team1, match: match, goals: 0, assists: 0, own_goals: 0, was_goalkeeper: true)
      expect(stat).to be_valid
    end

    it 'valid when player is only line player (no goalkeeper stats)' do
      stat = FactoryBot.build(:player_stat, player: player, team: team1, match: match, goals: 1, assists: 0, own_goals: 0, was_goalkeeper: false)
      expect(stat).to be_valid
    end
  end
end
