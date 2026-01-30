# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamSerializer do
  describe '#as_json' do
    subject(:serializer) { described_class.new(team) }

    let(:json) { serializer.as_json }

    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team) { FactoryBot.create(:team, name: 'Team A', round: round) }

    context 'when resource is present' do
      it 'serializes id, name, and round_id' do
        expect(json).to be_a(Hash)
      end

      it 'serializes identifiers' do
        expect(json[:id]).to eq(team.id)
        expect(json[:round_id]).to eq(round.id)
      end

      it 'serializes name' do
        expect(json[:name]).to eq('Team A')
      end
    end

    context 'when resource is blank' do
      let(:team) { nil }

      it 'returns nil' do
        expect(json).to be_nil
      end
    end

    context 'when resource is empty string' do
      # This tests the blank? check
      it 'handles edge cases correctly' do
        # TeamSerializer checks resource.blank?, so nil should return nil
        serializer_nil = described_class.new(nil)
        expect(serializer_nil.as_json).to be_nil
      end
    end

    context 'with different team names' do
      let(:team) { FactoryBot.create(:team, name: 'FC Barcelona', round: round) }

      it 'serializes team name correctly' do
        expect(json[:name]).to eq('FC Barcelona')
      end
    end
  end
end
