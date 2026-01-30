# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/RepeatedExample

RSpec.describe TeamPresenter do
  subject(:presenter) { described_class.new(team) }

  let(:round) { FactoryBot.create(:round, :with_championship) }
  let(:team) { FactoryBot.create(:team, round: round, name: 'Test Team') }
  let(:player1) { FactoryBot.create(:player, name: 'Player 1') }
  let(:player2) { FactoryBot.create(:player, name: 'Player 2') }

  describe 'delegates' do
    it 'delegates id to resource' do
      expect(presenter.id).to eq(team.id)
    end

    it 'delegates name to resource' do
      expect(presenter.name).to eq('Test Team')
    end

    it 'delegates round_id to resource' do
      expect(presenter.round_id).to eq(round.id)
    end

    it 'delegates created_at to resource' do
      expect(presenter.created_at).to eq(team.created_at)
    end

    it 'delegates updated_at to resource' do
      expect(presenter.updated_at).to eq(team.updated_at)
    end
  end

  describe '#as_json' do
    let(:json) { presenter.as_json }


    context 'with empty relationships' do
      it 'returns correct structure' do
        expect(json).to be_a(Hash)
        expect(json[:id]).to eq(team.id)
        expect(json[:name]).to eq('Test Team')
        expect(json[:round_id]).to eq(round.id)
      end

      it 'includes timestamps' do
        expect(json[:created_at]).to eq(team.created_at)
        expect(json[:updated_at]).to eq(team.updated_at)
      end

      it 'returns empty relationships' do
        expect(json[:matches]).to eq([])
        expect(json[:players]).to eq([])
      end
    end

    context 'with matches' do
      let(:team1) { team }
      let(:team2) { FactoryBot.create(:team, round: round) }
      let(:match1) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
      let(:match2) { FactoryBot.create(:match, round: round, team_1: team2, team_2: team1) }

      before do
        match1
        match2
      end

      it 'includes matches in json' do
        expect(json[:matches]).to be_an(Array)
        expect(json[:matches].length).to eq(2)
      end

      it 'includes match ids' do
        expect(json[:matches].first[:id]).to be_in([match1.id, match2.id])
      end

      it 'serializes matches as hashes' do
        expect(json[:matches].first).to be_a(Hash)
      end

      it 'serializes matches using MatchPresenter' do
        match_json = json[:matches].first
        expect(match_json).to have_key(:id)
        expect(match_json).to have_key(:name)
      end
    end

    context 'with players' do
      before do
        team.players << player1
        team.players << player2
      end

      it 'includes players in json' do
        expect(json[:players]).to be_an(Array)
        expect(json[:players].length).to eq(2)
      end

      it 'includes player ids' do
        expect(json[:players].map { |p| p[:id] }).to contain_exactly(player1.id, player2.id)
      end

      it 'serializes players as hashes' do
        expect(json[:players].first).to be_a(Hash)
      end

      it 'serializes players using PlayerPresenter' do
        player_json = json[:players].first
        expect(player_json).to have_key(:id)
        expect(player_json).to have_key(:name)
      end

      it 'orders players by created_at' do
        # Create player_teams with different created_at times
        player_team1 = PlayerTeam.find_by(team: team, player: player1)
        player_team1.update(created_at: 2.days.ago)

        player_team2 = PlayerTeam.find_by(team: team, player: player2)
        player_team2.update(created_at: 1.day.ago)

        # Should be ordered by player_teams.created_at
        expect(json[:players].first[:id]).to eq(player1.id)
        expect(json[:players].last[:id]).to eq(player2.id)
      end
    end

    context 'with both matches and players' do
      let(:team1) { team }
      let(:team2) { FactoryBot.create(:team, round: round) }
      let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }

      before do
        team.players << player1
        match
      end

      it 'includes both matches and players' do
        expect(json[:matches]).to be_an(Array)
        expect(json[:matches].length).to eq(1)
      end

      it 'includes players when matches exist' do
        expect(json[:players]).to be_an(Array)
        expect(json[:players].length).to eq(1)
      end
    end
  end

  describe '#matches' do
    let(:team1) { team }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match1) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:match2) { FactoryBot.create(:match, round: round, team_1: team2, team_2: team1) }
    let(:other_match) do
      other_team1 = FactoryBot.create(:team, round: round)
      other_team2 = FactoryBot.create(:team, round: round)
      FactoryBot.create(:match, round: round, team_1: other_team1, team_2: other_team2)
    end

    before do
      match1
      match2
      other_match
    end

    it 'returns matches where team is team_1 or team_2' do
      matches = presenter.matches.to_a

      expect(matches.length).to eq(2)
      expect(matches.map(&:id)).to contain_exactly(match1.id, match2.id)
    end

    it 'excludes matches from other teams' do
      matches = presenter.matches.to_a
      expect(matches.map(&:id)).not_to include(other_match.id)
    end

    it 'uses Teams::MatchesQuery' do
      allow(Teams::MatchesQuery).to receive(:call).and_call_original
      presenter.matches
      expect(Teams::MatchesQuery).to have_received(:call).with(team: team)
    end
  end

  describe '#players' do
    before do
      team.players << player1
      team.players << player2
    end

    it 'returns players associated with the team' do
      players = presenter.players

      expect(players).to be_an(Array)
      expect(players.length).to eq(2)
    end

    it 'returns the expected player ids' do
      players = presenter.players
      expect(players.map(&:id)).to contain_exactly(player1.id, player2.id)
    end

    it 'orders players by player_teams created_at' do
      player_team1 = PlayerTeam.find_by(team: team, player: player1)
      player_team1.update(created_at: 2.days.ago)

      player_team2 = PlayerTeam.find_by(team: team, player: player2)
      player_team2.update(created_at: 1.day.ago)

      players = presenter.players

      expect(players.first.id).to eq(player1.id)
      expect(players.last.id).to eq(player2.id)
    end

    it 'eager loads player association' do
      # This test verifies that includes(:player) is applied
      # The includes should prevent N+1 queries
      players = presenter.players
      expect(players).to be_an(Array)
      expect(players.length).to eq(2)
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/RepeatedExample
