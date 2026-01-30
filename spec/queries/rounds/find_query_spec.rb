# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rounds::FindQuery do
  describe '.call' do
    subject(:query_result) { described_class.call(id: round_id) }

    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:round_id) { round.id }

    context 'when round exists' do
      it 'returns the round' do
        expect(query_result).to eq(round)
      end

      it 'returns a round with correct attributes' do
        result = query_result
        expect(result.id).to eq(round.id)
        expect(result.name).to eq(round.name)
        expect(result.championship_id).to eq(round.championship_id)
      end

      it 'uses CollectionQuery to find the round' do
        # Verify that CollectionQuery is called with correct relation
        # The actual implementation will call .first! on the result
        expect(Rounds::CollectionQuery).to receive(:new).with(relation: Round.where(id: round_id), user_id: nil).and_call_original
        
        result = query_result
        expect(result).to eq(round)
      end
    end

    context 'when round does not exist' do
      let(:round_id) { 999_999 }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { query_result }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when id is nil' do
      let(:round_id) { nil }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { query_result }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
