 # frozen_string_literal: true

 require 'rails_helper'

 RSpec.describe LeagueEngine::Engine do
  let(:round) { create(:round) }
  let(:match) { create(:match, :with_round, :with_team_1, :with_team_2) }

  describe '.suggest_next_match' do
    # rubocop:disable RSpec/ExampleLength
    it 'delegates to LeagueEngine::MatchSequence' do
      sequence_double = instance_double(LeagueEngine::MatchSequence)
      allow(LeagueEngine::MatchSequence).to receive(:new)
        .with(round: round)
        .and_return(sequence_double)
      allow(sequence_double).to receive(:suggest).and_return({ needs_winner_selection: false })

      result = described_class.suggest_next_match(round: round)

      expect(LeagueEngine::MatchSequence).to have_received(:new).with(round: round)
      expect(sequence_double).to have_received(:suggest)
      expect(result).to eq({ needs_winner_selection: false })
    end
    # rubocop:enable RSpec/ExampleLength
  end

  describe '.create_next_match' do
    # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    it 'delegates to LeagueEngine::MatchSequence with winner_team_id' do
      sequence_double = instance_double(LeagueEngine::MatchSequence)
      allow(LeagueEngine::MatchSequence).to receive(:new)
        .with(round: round, winner_team_id: 123)
        .and_return(sequence_double)
      allow(sequence_double).to receive(:create_next_match).and_return({ match: instance_double(Match), queue: [] })

      result = described_class.create_next_match(round: round, winner_team_id: 123)

      expect(LeagueEngine::MatchSequence).to have_received(:new).with(round: round, winner_team_id: 123)
      expect(sequence_double).to have_received(:create_next_match)
      expect(result).to be_a(Hash)
      expect(result).to have_key(:match)
      expect(result).to have_key(:queue)
    end
    # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
  end

  describe '.redistribute_after_finalize' do
    it 'delegates to LeagueEngine::MatchSequence.redistribute_after_finalize' do
      allow(LeagueEngine::MatchSequence).to receive(:redistribute_after_finalize)

      described_class.redistribute_after_finalize(match:)

      expect(LeagueEngine::MatchSequence).to have_received(:redistribute_after_finalize).with(match)
    end
  end

  describe '.finalize_match' do
    it 'delegates to Matches::Finalize' do
      allow(Matches::Finalize).to receive(:call).and_return(match)

      result = described_class.finalize_match(match:)

      expect(Matches::Finalize).to have_received(:call).with(match:)
      expect(result).to eq(match)
    end
  end

  describe '.substitute_in_match' do
    # rubocop:disable RSpec/ExampleLength
    it 'delegates to Matches::SubstitutePlayer' do
      payload = {
        removed_player_id: 1,
        replacement_player_id: 2,
        team_id: 3
      }
      allow(Matches::SubstitutePlayer).to receive(:call).and_return(payload)

      result = described_class.substitute_in_match(
        match: match,
        player_id: 1,
        replacement_player_id: 2,
        team_id: 3
      )

      expect(Matches::SubstitutePlayer).to have_received(:call).with(
        match: match,
        player_id: 1,
        replacement_player_id: 2,
        team_id: 3
      )
      expect(result).to eq(payload)
    end
    # rubocop:enable RSpec/ExampleLength
  end

  describe '.replace_in_round' do
    # rubocop:disable RSpec/ExampleLength
    it 'delegates to Substitutions::ReplacePlayer' do
      round = match.round
      payload = {
        removed_player_id: 1,
        replacement_player_id: 2
      }
      allow(Substitutions::ReplacePlayer).to receive(:call).and_return(payload)

      result = described_class.replace_in_round(round:, player_id: 1, match_id: match.id)

      expect(Substitutions::ReplacePlayer).to have_received(:call).with(
        round: round,
        player_id: 1,
        match_id: match.id
      )
      expect(result).to eq(payload)
    end
    # rubocop:enable RSpec/ExampleLength
  end

  describe '.add_goalkeeper' do
    # rubocop:disable RSpec/ExampleLength
    it 'delegates to PlayerStats::AddGoalkeeper' do
      stat = instance_double(PlayerStat)
      allow(PlayerStats::AddGoalkeeper).to receive(:call).and_return(stat)

      result = described_class.add_goalkeeper(
        match_id: match.id,
        team_id: match.team_1_id,
        player_id: 123
      )

      expect(PlayerStats::AddGoalkeeper).to have_received(:call).with(
        match_id: match.id,
        team_id: match.team_1_id,
        player_id: 123
      )
      expect(result).to eq(stat)
    end
    # rubocop:enable RSpec/ExampleLength
  end

  describe '.bulk_update_player_stats' do
    # rubocop:disable RSpec/ExampleLength
    it 'delegates to PlayerStats::BulkUpsert' do
      payload = [{ player_id: 1, team_id: match.team_1_id, goals: 1 }]
      relation_double = instance_double(ActiveRecord::Relation)
      allow(PlayerStats::BulkUpsert).to receive(:call).and_return(relation_double)

      result = described_class.bulk_update_player_stats(
        match_id: match.id,
        payload: payload
      )

      expect(PlayerStats::BulkUpsert).to have_received(:call).with(
        match_id: match.id,
        payload: payload
      )
      expect(result).to eq(relation_double)
    end
    # rubocop:enable RSpec/ExampleLength
  end
 end
