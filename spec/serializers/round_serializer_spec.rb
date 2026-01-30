# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoundSerializer do
  describe '#as_json' do
    subject(:serializer) { described_class.new(round) }

    let(:json) { serializer.as_json }

    let(:championship) { FactoryBot.create(:championship) }
    let(:round_date) { Date.new(2025, 3, 15) }
    let(:round) do
      FactoryBot.create(
        :round,
        name: 'Round 1',
        round_date: round_date,
        championship: championship
      )
    end

    it 'serializes as a hash' do
      expect(json).to be_a(Hash)
    end

    it 'serializes identifiers' do
      expect(json[:id]).to eq(round.id)
      expect(json[:championship_id]).to eq(championship.id)
    end

    it 'serializes name and date' do
      expect(json[:name]).to eq('Round 1')
      expect(json[:round_date]).to eq(round_date)
    end

    it 'serializes timestamps' do
      expect(json[:created_at]).to eq(round.created_at)
      expect(json[:updated_at]).to eq(round.updated_at)
    end

    context 'with different date formats' do
      let(:round_date) { Date.new(2025, 12, 31) }

      it 'serializes date correctly' do
        expect(json[:round_date]).to eq(Date.new(2025, 12, 31))
      end
    end

    context 'with future date' do
      let(:round_date) { Date.new(2026, 1, 1) }

      it 'serializes future date correctly' do
        expect(json[:round_date]).to eq(Date.new(2026, 1, 1))
      end
    end

    it 'includes timestamps' do
      expect(json).to have_key(:created_at)
      expect(json).to have_key(:updated_at)
    end

    it 'returns timestamp types' do
      expect(json[:created_at]).to be_a(ActiveSupport::TimeWithZone)
      expect(json[:updated_at]).to be_a(ActiveSupport::TimeWithZone)
    end
  end
end
