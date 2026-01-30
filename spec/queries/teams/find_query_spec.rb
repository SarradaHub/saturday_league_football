# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teams::FindQuery do
  describe '.call' do
    subject(:query_result) { described_class.call(id: team_id) }

    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team) { FactoryBot.create(:team, round: round) }
    let(:team_id) { team.id }

    context 'when team exists' do
      it 'returns the team' do
        expect(query_result).to eq(team)
      end

      it 'returns a team with correct attributes' do
        result = query_result
        expect(result.id).to eq(team.id)
        expect(result.name).to eq(team.name)
        expect(result.round_id).to eq(team.round_id)
      end

      it 'uses CollectionQuery to find the team' do
        # Verify that CollectionQuery is called with correct relation
        # The actual implementation will call .first! on the result
        expect(Teams::CollectionQuery).to receive(:new).with(relation: Team.where(id: team_id), user_id: nil).and_call_original
        
        result = query_result
        expect(result).to eq(team)
      end
    end

    context 'when team does not exist' do
      let(:team_id) { 999_999 }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { query_result }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when id is nil' do
      let(:team_id) { nil }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { query_result }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
