# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Championships::FindQuery do
  describe '.call' do
    subject(:query_result) { described_class.call(id: championship_id) }

    let(:championship) { FactoryBot.create(:championship) }
    let(:championship_id) { championship.id }

    context 'when championship exists' do
      it 'returns the championship' do
        expect(query_result).to eq(championship)
      end

      it 'returns a championship with correct attributes' do
        result = query_result
        expect(result.id).to eq(championship.id)
        expect(result.name).to eq(championship.name)
        expect(result.description).to eq(championship.description)
      end

      it 'uses CollectionQuery to find the championship' do
        # Verify that CollectionQuery is called with correct relation and includes
        # The actual implementation will call .first! on the result
        expect(Championships::CollectionQuery).to receive(:new).with(
          relation: Championship.where(id: championship_id),
          includes: [],
          user_id: nil
        ).and_call_original

        result = query_result
        expect(result).to eq(championship)
      end
    end

    context 'when championship does not exist' do
      let(:championship_id) { 999_999 }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { query_result }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when id is nil' do
      let(:championship_id) { nil }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { query_result }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
