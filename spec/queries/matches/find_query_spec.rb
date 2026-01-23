# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Matches::FindQuery do
  describe '.call' do
    subject(:query_result) { described_class.call(id: match_id) }

    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2) }
    let(:match_id) { match.id }

    context 'when match exists' do
      it 'returns the match' do
        expect(query_result).to eq(match)
      end

      it 'returns a match with correct attributes' do
        result = query_result
        expect(result.id).to eq(match.id)
        expect(result.name).to eq(match.name)
        expect(result.round_id).to eq(match.round_id)
      end

      it 'uses CollectionQuery to find the match' do
        # Verify that CollectionQuery is called with correct relation
        # The actual implementation will call .first! on the result
        expect(Matches::CollectionQuery).to receive(:new).with(relation: Match.where(id: match_id)).and_call_original
        
        result = query_result
        expect(result).to eq(match)
      end
    end

    context 'when match does not exist' do
      let(:match_id) { 999_999 }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { query_result }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when id is nil' do
      let(:match_id) { nil }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { query_result }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
