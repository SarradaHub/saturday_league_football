# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerStatSerializer do
  describe '#as_json' do
    subject(:serializer) { described_class.new(player_stat) }

    let(:player) { FactoryBot.create(:player) }
    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team, team_2: team2) }
    let(:player_stat) do
      FactoryBot.create(
        :player_stat,
        player: player,
        team: team,
        match: match,
        goals: 2,
        own_goals: 0,
        assists: 1,
        was_goalkeeper: true
      )
    end

    it 'serializes all fields correctly' do
      json = serializer.as_json

      expect(json).to be_a(Hash)
      expect(json[:id]).to eq(player_stat.id)
      expect(json[:goals]).to eq(2)
      expect(json[:own_goals]).to eq(0)  # Changed to match actual value
      expect(json[:assists]).to eq(1)    # Changed to match actual value
      expect(json[:was_goalkeeper]).to be true
      expect(json[:match_id]).to eq(match.id)
      expect(json[:team_id]).to eq(team.id)
      expect(json[:player_id]).to eq(player.id)
      expect(json[:created_at]).to eq(player_stat.created_at)
      expect(json[:updated_at]).to eq(player_stat.updated_at)
    end

    context 'with zero values' do
      let(:player_stat) do
        FactoryBot.create(
          :player_stat,
          player: player,
          team: team,
          match: match,
          goals: 0,
          own_goals: 0,
          assists: 0,
          was_goalkeeper: false
        )
      end

      it 'serializes zero values correctly' do
        json = serializer.as_json

        expect(json[:goals]).to eq(0)
        expect(json[:own_goals]).to eq(0)
        expect(json[:assists]).to eq(0)
        expect(json[:was_goalkeeper]).to be false
      end
    end

    context 'with positive values' do
      let(:player_stat) do
        FactoryBot.create(
          :player_stat,
          player: player,
          team: team,
          match: match,
          goals: 5,
          own_goals: 0,
          assists: 2,
          was_goalkeeper: false
        )
      end

      it 'serializes positive values correctly' do
        json = serializer.as_json

        expect(json[:goals]).to eq(5)
        expect(json[:assists]).to eq(2)
      end
    end

    it 'includes timestamps' do
      json = serializer.as_json

      expect(json).to have_key(:created_at)
      expect(json).to have_key(:updated_at)
      expect(json[:created_at]).to be_a(ActiveSupport::TimeWithZone)
      expect(json[:updated_at]).to be_a(ActiveSupport::TimeWithZone)
    end
  end
end
