# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchPresenter do
  subject(:presenter) { described_class.new(match) }

  let(:team_1) { FactoryBot.create(:team) }
  let(:team_2) { FactoryBot.create(:team) }
  let(:round) { FactoryBot.create(:round, :with_championship) }
  let(:match) { FactoryBot.create(:match, round: round, team_1: team_1, team_2: team_2, draw: false) }

  let(:team_1_player) { FactoryBot.create(:player) }
  let(:team_2_player) { FactoryBot.create(:player) }

  before do
    team_1.players << team_1_player
    team_2.players << team_2_player

    FactoryBot.create(:player_stat, player: team_1_player, team: team_1, match: match, goals: 2, assists: 1, own_goals: 0)
    FactoryBot.create(:player_stat, player: team_2_player, team: team_2, match: match, goals: 1, assists: 0, own_goals: 1)
  end


  describe '#team_1_goals' do
    it 'sums goals and opponent own goals' do
      expect(presenter.team_1_goals).to eq(3)
    end
  end

  describe '#team_2_goals' do
    it 'sums goals and opponent own goals' do
      expect(presenter.team_2_goals).to eq(1)
    end
  end

  describe '#statistics' do
    it 'returns structured breakdown for each team' do
      stats = presenter.as_json[:statistics]

      expect(stats[:team_1][:goal_scorers]).to include(team_1_player.name => 2)
      expect(stats[:team_2][:own_goals]).to include(team_2_player.name => 1)
      expect(stats[:scoreboard]).to eq({ team_1: 3, team_2: 1 })
    end
  end

  describe '#winning_team' do
    context 'when winning_team is present' do
      let(:match) { FactoryBot.create(:match, round: round, team_1: team_1, team_2: team_2, winning_team: team_1) }

      it 'serializes winning team' do
        json = presenter.as_json
        expect(json[:winning_team]).to be_a(Hash)
        expect(json[:winning_team][:id]).to eq(team_1.id)
      end
    end

    context 'when winning_team is nil' do
      let(:match) { FactoryBot.create(:match, round: round, team_1: team_1, team_2: team_2, winning_team: nil) }

      it 'handles nil winning_team' do
        # TeamSerializer should handle nil resource
        json = presenter.as_json
        expect(json[:winning_team]).to be_nil
      end
    end
  end

  describe '#draw' do
    context 'when match is a draw' do
      let(:match) { FactoryBot.create(:match, round: round, team_1: team_1, team_2: team_2, draw: true, winning_team: nil) }

      it 'includes draw true in as_json' do
        json = presenter.as_json
        expect(json[:draw]).to be true
        expect(json[:winning_team]).to be_nil
      end
    end

    context 'when match is not a draw' do
      let(:match) { FactoryBot.create(:match, round: round, team_1: team_1, team_2: team_2, draw: false, winning_team: team_1) }

      it 'includes draw false in as_json' do
        json = presenter.as_json
        expect(json[:draw]).to be false
        expect(json[:winning_team]).to be_a(Hash)
      end
    end
  end

  describe '#team_1' do
    context 'when team_1 is present' do
      it 'serializes team_1' do
        json = presenter.as_json
        expect(json[:team_1]).to be_a(Hash)
        expect(json[:team_1][:id]).to eq(team_1.id)
      end
    end
  end

  describe '#team_2' do
    context 'when team_2 is present' do
      it 'serializes team_2' do
        json = presenter.as_json
        expect(json[:team_2]).to be_a(Hash)
        expect(json[:team_2][:id]).to eq(team_2.id)
      end
    end
  end

  describe '#team_1_players and #team_2_players as public API' do
    it 'team_1_players returns same as team_players(team_1)' do
      expect(presenter.team_1_players).to eq(presenter.send(:team_players, team_1))
      expect(presenter.team_1_players).to be_an(Array)
      expect(presenter.team_1_players.first[:id]).to eq(team_1_player.id)
    end

    it 'team_2_players returns same as team_players(team_2)' do
      expect(presenter.team_2_players).to eq(presenter.send(:team_players, team_2))
      expect(presenter.team_2_players).to be_an(Array)
      expect(presenter.team_2_players.first[:id]).to eq(team_2_player.id)
    end
  end

  describe '#team_players' do
    context 'when team is present' do
      it 'returns array of serialized players' do
        # team_1_player is already added in main before block
        players = presenter.send(:team_players, team_1)
        expect(players).to be_an(Array)
        expect(players.first).to be_a(Hash)
        expect(players.first[:id]).to eq(team_1_player.id)
      end
    end

    context 'when team is blank' do
      it 'returns empty array' do
        players = presenter.send(:team_players, nil)
        expect(players).to eq([])
      end
    end
  end

  describe '#hash_to_player_array' do
    context 'with valid hash' do
      it 'converts hash to array of player serializations' do
        # team_1_player is already added in main before block
        hash = { team_1_player.name => 2 }
        result = presenter.send(:hash_to_player_array, team_1, hash)
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first[:id]).to eq(team_1_player.id)
      end
    end

    context 'with empty hash' do
      it 'returns empty array' do
        result = presenter.send(:hash_to_player_array, team_1, {})
        expect(result).to eq([])
      end
    end

    context 'when hash is blank' do
      it 'returns empty array' do
        result = presenter.send(:hash_to_player_array, team_1, nil)
        expect(result).to eq([])
      end
    end

    context 'when hash is not a Hash' do
      it 'returns empty array' do
        result = presenter.send(:hash_to_player_array, team_1, 'not a hash')
        expect(result).to eq([])
      end
    end

    context 'when player is not found' do
      it 'skips players not found in team' do
        # team_1_player is already added in main before block
        hash = { 'Non-existent Player' => 1, team_1_player.name => 1 }
        result = presenter.send(:hash_to_player_array, team_1, hash)
        expect(result.length).to eq(1)
        expect(result.first[:id]).to eq(team_1_player.id)
      end
    end

    context 'with count zero' do
      it 'returns empty array when count is 0' do
        hash = { team_1_player.name => 0 }
        result = presenter.send(:hash_to_player_array, team_1, hash)
        expect(result).to eq([])
      end
    end
  end

  describe '#find_player_by_name' do
    context 'when team and name are present' do
      it 'finds player by name' do
        # team_1_player is already added in main before block
        result = presenter.send(:find_player_by_name, team_1, team_1_player.name)
        expect(result).to eq(team_1_player)
      end
    end

    context 'when team is blank' do
      it 'returns nil' do
        result = presenter.send(:find_player_by_name, nil, team_1_player.name)
        expect(result).to be_nil
      end
    end

    context 'when name is blank' do
      it 'returns nil' do
        result = presenter.send(:find_player_by_name, team_1, nil)
        expect(result).to be_nil
      end
    end

    context 'when player is not found' do
      it 'returns nil' do
        result = presenter.send(:find_player_by_name, team_1, 'Non-existent Player')
        expect(result).to be_nil
      end
    end
  end

  describe '#team_1_goals_scorer_array' do
    it 'converts goals_scorer hash to array' do
      # team_1_player and stats are already created in main before block
      json = presenter.as_json
      expect(json[:team_1_goals_scorer]).to be_an(Array)
      expect(json[:team_1_goals_scorer].length).to eq(2)
      expect(json[:team_1_goals_scorer].first[:id]).to eq(team_1_player.id)
    end
  end

  describe '#team_1_assists_array' do
    it 'converts assists hash to array' do
      # team_1_player and stats are already created in main before block
      json = presenter.as_json
      expect(json[:team_1_assists]).to be_an(Array)
      expect(json[:team_1_assists].length).to eq(1)
      expect(json[:team_1_assists].first[:id]).to eq(team_1_player.id)
    end
  end

  describe '#team_1_own_goals_scorer_array' do
    it 'converts own_goals from team_2 to array for team_1' do
      # team_2_player and stats are already created in main before block
      json = presenter.as_json
      expect(json[:team_1_own_goals_scorer]).to be_an(Array)
      expect(json[:team_1_own_goals_scorer].length).to eq(1)
      expect(json[:team_1_own_goals_scorer].first[:id]).to eq(team_2_player.id)
    end
  end

  describe '#team_2_goals_scorer_array' do
    it 'converts goals_scorer hash to array' do
      # team_2_player and stats are already created in main before block
      json = presenter.as_json
      expect(json[:team_2_goals_scorer]).to be_an(Array)
    end

    it 'includes scorer id' do
      json = presenter.as_json
      expect(json[:team_2_goals_scorer].length).to eq(1)
      expect(json[:team_2_goals_scorer].first[:id]).to eq(team_2_player.id)
    end
  end

  describe '#team_2_assists_array' do
    it 'converts assists hash to array' do
      # team_2_player and stats are already created in main before block
      json = presenter.as_json
      expect(json[:team_2_assists]).to be_an(Array)
      # team_2_player has 0 assists in main before block, so array should be empty
      expect(json[:team_2_assists]).to eq([])
    end
  end

  describe '#team_2_own_goals_scorer_array' do
    it 'converts own_goals from team_1 to array for team_2' do
      # team_1_player has 0 own_goals in main before block, so array should be empty
      json = presenter.as_json
      expect(json[:team_2_own_goals_scorer]).to be_an(Array)
      expect(json[:team_2_own_goals_scorer]).to eq([])
    end
  end

  context 'with match without teams' do
    # Match requires team_1 and team_2, so we can't test nil teams
    # Instead, test with teams that have no players
    let(:presenter_without_players) do
      empty_teams = FactoryBot.create_list(:team, 2, round: round)
      match_without_players = FactoryBot.create(:match, round: round, team_1: empty_teams.first, team_2: empty_teams.last)
      described_class.new(match_without_players)
    end

    it 'handles match without players in teams' do
      json = presenter_without_players.as_json
      expect(json[:team_1]).to be_present
      expect(json[:team_2]).to be_present
    end

    it 'returns empty player arrays' do
      json = presenter_without_players.as_json
      expect(json[:team_1_players]).to eq([])
      expect(json[:team_2_players]).to eq([])
    end
  end

  context 'with match without players' do
    let(:presenter_without_players) do
      empty_teams = FactoryBot.create_list(:team, 2, round: round)
      match_without_players = FactoryBot.create(:match, round: round, team_1: empty_teams.first, team_2: empty_teams.last)
      described_class.new(match_without_players)
    end

    it 'handles match without players in teams' do
      json = presenter_without_players.as_json
      expect(json[:team_1_players]).to eq([])
      expect(json[:team_2_players]).to eq([])
    end
  end

  context 'with match without stats' do
    let(:presenter_no_stats) do
      match_no_stats = FactoryBot.create(:match, round: round, team_1: team_1, team_2: team_2)
      described_class.new(match_no_stats)
    end

    it 'handles match without player stats' do
      json = presenter_no_stats.as_json
      expect(json[:team_1_goals]).to eq(0)
      expect(json[:team_2_goals]).to eq(0)
    end

    it 'returns empty scorer arrays' do
      json = presenter_no_stats.as_json
      expect(json[:team_1_goals_scorer]).to eq([])
      expect(json[:team_2_goals_scorer]).to eq([])
    end
  end
end
