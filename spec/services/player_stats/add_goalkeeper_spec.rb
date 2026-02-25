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
    it 'creates one PlayerStat' do
      expect { call_result }.to change(PlayerStat, :count).by(1)
    end

    it 'sets match, team and player on the stat' do
      call_result
      stat = PlayerStat.last
      expect(stat.match_id).to eq(match.id)
      expect(stat.team_id).to eq(team.id)
      expect(stat.player_id).to eq(player.id)
    end

    it 'sets was_goalkeeper to true' do
      call_result
      expect(PlayerStat.last.was_goalkeeper).to be(true)
    end

    it 'sets goals, assists and own_goals to zero' do
      call_result
      stat = PlayerStat.last
      expect(stat.goals).to eq(0)
      expect(stat.assists).to eq(0)
      expect(stat.own_goals).to eq(0)
    end

    it 'is idempotent and does not create a second stat' do
      described_class.call(match_id: match.id, team_id: team.id, player_id: player.id)
      expect { call_result }.not_to change(PlayerStat, :count)
    end

    it 'keeps was_goalkeeper true on existing stat when called again' do
      described_class.call(match_id: match.id, team_id: team.id, player_id: player.id)
      call_result
      expect(PlayerStat.last.was_goalkeeper).to be(true)
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

    # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    it 'restores a soft-deleted PlayerTeam when adding the same player to the same team again' do
      pt = PlayerTeam.create!(team: team, player: player)
      pt.soft_delete
      expect(PlayerTeam.with_deleted.find_by(team: team, player: player)).to be_deleted

      expect { call_result }.to change(PlayerTeam, :count).by(1)
      expect(player.teams.reload).to include(team)
      expect(pt.reload).not_to be_deleted
    end
    # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
  end
end
