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

    # Total do time: 3 gols >= 3 assistências (válido)
    FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 2, assists: 1, own_goals: 0)
    FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 1, assists: 2, own_goals: 0)
  end

  it 'aggregates match totals' do
    expect(call_result).to include(goals_in_match: 3, assists_in_match: 3, own_goals_in_match: 0)
  end

  it 'counts matches played for the given team/round' do
    expect(call_result[:total_matches_for_team]).to eq(1)
  end

  context 'when player has no stats in match' do
    before do
      # Use raw SQL to delete stats without triggering callbacks
      # The model has incorrect belongs_to with dependent: :destroy which causes issues with destroy_all
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array([
          'DELETE FROM player_stats WHERE player_id = ? AND match_id = ?',
          player.id,
          match.id
        ])
      )
    end

    it 'returns zero for all aggregates' do
      result = call_result

      expect(result[:goals_in_match]).to eq(0)
      expect(result[:assists_in_match]).to eq(0)
      expect(result[:own_goals_in_match]).to eq(0)
    end

    it 'still counts matches for team if player is in team' do
      result = call_result

      expect(result[:total_matches_for_team]).to eq(1)
    end
  end

  context 'when player is not in team' do
    before do
      player.teams.delete(team)
    end

    it 'returns zero for total_matches_for_team' do
      result = call_result

      expect(result[:total_matches_for_team]).to eq(0)
    end

    it 'still aggregates stats for the match' do
      result = call_result

      expect(result[:goals_in_match]).to eq(3)
      expect(result[:assists_in_match]).to eq(3)
    end
  end

  context 'when team has multiple matches in round' do
    let(:team2) { FactoryBot.create(:team, round: round) }

    before do
      FactoryBot.create(:match, round: round, team_1: team, team_2: team2)
      FactoryBot.create(:match, round: round, team_1: team, team_2: team2)
    end

    it 'counts all matches for the team in the round' do
      result = call_result

      # team has match (current), match2, and match3 = 3 matches total
      expect(result[:total_matches_for_team]).to eq(3)
    end
  end

  context 'when team has matches in different rounds' do
    let(:other_round) { FactoryBot.create(:round, :with_championship) }
    let(:other_team) { FactoryBot.create(:team, round: other_round) }

    before do
      FactoryBot.create(:match, round: other_round, team_1: team, team_2: other_team)
    end

    it 'only counts matches in the specified round' do
      result = call_result

      # Should only count match in current round, not other_match
      expect(result[:total_matches_for_team]).to eq(1)
    end
  end

  context 'with own goals' do
    before do
      FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 0, assists: 0, own_goals: 1)
    end

    it 'aggregates own goals correctly' do
      result = call_result

      expect(result[:own_goals_in_match]).to eq(1)
    end
  end

  context 'with multiple stats in same match' do
    before do
      # Add another stat for the same player in the same match
      FactoryBot.create(:player_stat, player: player, team: team, match: match, goals: 2, assists: 1, own_goals: 0)
    end

    it 'aggregates all stats correctly' do
      result = call_result

      # Original: 3 goals, 3 assists
      # New: 2 goals, 1 assist
      # Total: 5 goals, 4 assists
      expect(result[:goals_in_match]).to eq(5)
      expect(result[:assists_in_match]).to eq(4)
    end
  end

  context 'when player has stats in different matches' do
    let(:other_match) { FactoryBot.create(:match, round: round, team_1: team, team_2: FactoryBot.create(:team, round: round)) }

    before do
      FactoryBot.create(:player_stat, player: player, team: team, match: other_match, goals: 5, assists: 2, own_goals: 0)
    end

    it 'only aggregates stats for the specified match' do
      result = call_result

      # Should only include stats from match, not other_match
      expect(result[:goals_in_match]).to eq(3) # Only from match
      expect(result[:assists_in_match]).to eq(3) # Only from match
    end
  end
end
