# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Players::MatchStatistics do
  subject(:call_result) do
    described_class.call(player: player, team: team, round: round, match: match)
  end

  let(:player) { FactoryBot.create(:player) }
  let(:team) { FactoryBot.create(:team) }
  let(:round) { FactoryBot.create(:round, :with_championship) }
  let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: FactoryBot.create(:team)) }

  before do
    team.players << player

    FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 1, assists: 2, own_goals: 0)
    FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 0, assists: 1, own_goals: 0)
  end


  it 'aggregates match totals' do
    expect(call_result).to include(goals_in_match: 1, assists_in_match: 3, own_goals_in_match: 0)
  end

  it 'counts matches played for the given team/round' do
    expect(call_result[:total_matches_for_team]).to eq(1)
  end
end
