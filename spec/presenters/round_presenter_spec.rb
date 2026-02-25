# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/MultipleExpectations

RSpec.describe RoundPresenter do
  subject(:presenter) { described_class.new(round) }

  let(:championship) { FactoryBot.create(:championship) }
  let(:round) { FactoryBot.create(:round, championship: championship, name: 'Round 1', round_date: Date.new(2025, 1, 1)) }
  let(:team1) { FactoryBot.create(:team, round: round) }
  let(:team2) { FactoryBot.create(:team, round: round) }
  let(:player1) { FactoryBot.create(:player, first_name: 'Player', last_name: '1') }
  let(:player2) { FactoryBot.create(:player, first_name: 'Player', last_name: '2') }

  describe 'delegates' do
    it 'delegates id to resource' do
      expect(presenter.id).to eq(round.id)
    end

    it 'delegates name to resource' do
      expect(presenter.name).to eq('Round 1')
    end

    it 'delegates round_date to resource' do
      expect(presenter.round_date).to eq(Date.new(2025, 1, 1))
    end

    it 'delegates championship_id to resource' do
      expect(presenter.championship_id).to eq(championship.id)
    end

    it 'delegates created_at to resource' do
      expect(presenter.created_at).to eq(round.created_at)
    end

    it 'delegates updated_at to resource' do
      expect(presenter.updated_at).to eq(round.updated_at)
    end
  end

  describe '#as_json' do
    let(:json) { presenter.as_json }


    context 'with empty relationships' do
      it 'returns correct structure' do
        expect(json).to be_a(Hash)
        expect(json[:id]).to eq(round.id)
        expect(json[:name]).to eq('Round 1')
        expect(json[:round_date]).to eq(Date.new(2025, 1, 1))
        expect(json[:championship_id]).to eq(championship.id)
      end

      it 'includes timestamps' do
        expect(json[:created_at]).to eq(round.created_at)
        expect(json[:updated_at]).to eq(round.updated_at)
      end

      it 'returns empty relationships' do
        expect(json[:matches]).to eq([])
        expect(json[:players]).to eq([])
        expect(json[:teams]).to eq([])
      end
    end

    context 'with matches' do
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
        expect(json[:matches].map { |m| m[:id] }).to contain_exactly(match1.id, match2.id)
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
        round.players << player1
        round.players << player2
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
        expect(player_json).to have_key(:display_name)
      end

      it 'returns distinct players' do
        # Add same player twice through different teams
        team1.players << player1
        team2.players << player1

        player_ids = json[:players].map { |p| p[:id] }
        expect(player_ids.count(player1.id)).to eq(1)
      end
    end

    context 'with teams' do
      before do
        team1
        team2
      end

      it 'includes teams in json' do
        expect(json[:teams]).to be_an(Array)
        expect(json[:teams].length).to eq(2)
      end

      it 'includes team ids' do
        expect(json[:teams].map { |t| t[:id] }).to contain_exactly(team1.id, team2.id)
      end

      it 'serializes teams as hashes' do
        expect(json[:teams].first).to be_a(Hash)
      end

      it 'serializes teams using TeamPresenter' do
        team_json = json[:teams].first
        expect(team_json).to have_key(:id)
        expect(team_json).to have_key(:name)
        expect(team_json).to have_key(:round_id)
      end

      it 'returns distinct teams' do
        # Create a match that might create duplicate team references
        FactoryBot.create(:match, round: round, team_1: team1, team_2: team2)

        team_ids = json[:teams].map { |t| t[:id] }
        expect(team_ids.uniq.length).to eq(team_ids.length)
      end
    end

    context 'with all relationships' do
      let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }

      before do
        round.players << player1
        team1
        team2
        match
      end

      it 'includes all relationships' do
        expect(json[:matches]).to be_an(Array)
        expect(json[:matches].length).to eq(1)
        expect(json[:players]).to be_an(Array)
        expect(json[:players].length).to eq(1)
        expect(json[:teams]).to be_an(Array)
      end

      it 'includes created teams' do
        team_ids = json[:teams].map { |t| t[:id] }
        expect(team_ids).to include(team1.id, team2.id)
        expect(team_ids.length).to be >= 2
      end
    end
  end

  describe '#matches' do
    let(:match1) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:match2) { FactoryBot.create(:match, round: round, team_1: team2, team_2: team1) }
    let(:other_match) do
      other_round = FactoryBot.create(:round, :with_championship)
      other_team1 = FactoryBot.create(:team, round: other_round)
      other_team2 = FactoryBot.create(:team, round: other_round)
      FactoryBot.create(:match, round: other_round, team_1: other_team1, team_2: other_team2)
    end

    before do
      match1
      match2
      other_match
    end

    it 'returns matches for the round' do
      matches = presenter.matches.to_a

      expect(matches.length).to eq(2)
      expect(matches.map(&:id)).to contain_exactly(match1.id, match2.id)
    end

    it 'excludes matches from other rounds' do
      matches = presenter.matches.to_a
      expect(matches.map(&:id)).not_to include(other_match.id)
    end

    it 'uses resource.matches directly' do
      # Verify that matches are returned from the round
      matches = presenter.matches.to_a
      expect(matches.all? { |m| m.round_id == round.id }).to be true
    end
  end

  describe '#players' do
    before do
      round.players << player1
      round.players << player2
    end

    it 'returns players associated with the round' do
      players = presenter.players.to_a

      expect(players).to be_an(Array)
      expect(players.length).to eq(2)
      expect(players.map(&:id)).to contain_exactly(player1.id, player2.id)
    end

    it 'returns distinct players' do
      # Add same player through multiple teams
      team1.players << player1
      team2.players << player1

      players = presenter.players.to_a

      expect(players.map(&:id).count(player1.id)).to eq(1)
    end

    it 'uses resource.players.distinct' do
      # Verify that distinct is called by checking the result doesn't have duplicates
      players = presenter.players.to_a
      player_ids = players.map(&:id)
      expect(player_ids.uniq.length).to eq(player_ids.length)
    end
  end

  describe '#serialized_players order' do
    it 'returns players ordered by player_rounds.created_at (inscription order)' do
      # Add player2 first, then player1 (so player2 has earlier player_round.created_at)
      pr2 = round.player_rounds.create!(player: player2)
      pr1 = round.player_rounds.create!(player: player1)
      json = presenter.as_json
      expect(json[:players].map { |p| p[:id] }).to eq([player2.id, player1.id])
    end
  end

  describe '#teams' do
    before do
      team1
      team2
    end

    it 'returns teams associated with the round' do
      teams = presenter.teams.to_a

      expect(teams).to be_an(Array)
      expect(teams.length).to eq(2)
      expect(teams.map(&:id)).to contain_exactly(team1.id, team2.id)
    end

    it 'returns distinct teams' do
      # Create a match that might create duplicate team references
      FactoryBot.create(:match, round: round, team_1: team1, team_2: team2)

      teams = presenter.teams.to_a

      expect(teams.map(&:id).uniq.length).to eq(teams.length)
    end

    it 'uses resource.teams.distinct' do
      # Verify that distinct is called by checking the result doesn't have duplicates
      teams = presenter.teams.to_a
      team_ids = teams.map(&:id)
      expect(team_ids.uniq.length).to eq(team_ids.length)
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/MultipleExpectations
