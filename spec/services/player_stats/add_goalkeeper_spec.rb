# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerStats::AddGoalkeeper do
  subject(:call_result) do
    described_class.call(match_id: match.id, team_id: team.id, player_id: player.id)
  end

  let(:match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }
  let(:team)  { match.team_1 }
  let(:player) { FactoryBot.create(:player) }

  describe '#call' do
    it 'creates or updates a goalkeeper stat for the given match/team/player' do
      expect {
        call_result
      }.to change(PlayerStat, :count).by(1)

      stat = PlayerStat.last
      expect(stat.match_id).to eq(match.id)
      expect(stat.team_id).to eq(team.id)
      expect(stat.player_id).to eq(player.id)
      expect(stat.was_goalkeeper).to be(true)
      expect(stat.goals).to eq(0)
      expect(stat.assists).to eq(0)
      expect(stat.own_goals).to eq(0)
    end

    it 'is idempotent for the same match/team/player' do
      described_class.call(match_id: match.id, team_id: team.id, player_id: player.id)

      expect {
        call_result
      }.not_to change(PlayerStat, :count)

      stat = PlayerStat.last
      expect(stat.was_goalkeeper).to be(true)
    end

    it 'adds the player to the team for the round via PlayerTeam' do
      expect {
        call_result
      }.to change(PlayerTeam, :count).by(1)

      expect(player.teams).to include(team)
    end

    it 'does not create duplicate PlayerTeam records on subsequent calls' do
      described_class.call(match_id: match.id, team_id: team.id, player_id: player.id)

      expect {
        call_result
      }.not_to change(PlayerTeam, :count)
    end
  end
end

