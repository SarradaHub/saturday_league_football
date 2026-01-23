# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rounds::CollectionQuery do
  describe '.call' do
    subject(:query_result) { described_class.new(**params).call }

    let(:championship) { FactoryBot.create(:championship) }
    let!(:round1) { FactoryBot.create(:round, championship: championship, round_date: Date.new(2025, 1, 1)) }
    let!(:round2) { FactoryBot.create(:round, championship: championship, round_date: Date.new(2025, 1, 15)) }
    let!(:round3) { FactoryBot.create(:round, championship: championship, round_date: Date.new(2025, 1, 10)) }
    let(:params) { {} }

    context 'with default parameters' do
      it 'returns all rounds ordered by round_date descending' do
        result = query_result.to_a
        # Check that our created rounds are in the result
        round_ids = result.map(&:id)
        expect(round_ids).to include(round1.id, round2.id, round3.id)
        # Verify ordering for our rounds
        our_rounds = result.select { |r| [round1.id, round2.id, round3.id].include?(r.id) }
        expect(our_rounds.map(&:round_date)).to eq([Date.new(2025, 1, 15), Date.new(2025, 1, 10), Date.new(2025, 1, 1)])
      end

      it 'returns ActiveRecord::Relation' do
        expect(query_result).to be_a(ActiveRecord::Relation)
      end
    end

    context 'with custom relation' do
      let(:params) { { relation: Round.where(id: [round1.id, round2.id]) } }

      it 'filters by custom relation' do
        result = query_result.to_a
        expect(result.length).to eq(2)
        expect(result.map(&:id)).to contain_exactly(round1.id, round2.id)
      end

      it 'still orders by round_date descending' do
        result = query_result.to_a
        expect(result.map(&:round_date)).to eq([Date.new(2025, 1, 15), Date.new(2025, 1, 1)])
      end
    end

    context 'with includes' do
      context 'with simple includes' do
        let(:params) { { includes: ['championship'] } }

        it 'applies eager loading for championship' do
          result = query_result.to_a
          expect(result.first.association(:championship).loaded?).to be true
        end

        it 'returns rounds with loaded associations' do
          result = query_result.to_a
          # Find one of our created rounds
          our_round = result.find { |r| [round1.id, round2.id, round3.id].include?(r.id) }
          expect(our_round).to be_present
          expect(our_round.association(:championship).loaded?).to be true
          expect(our_round.championship).to eq(championship)
        end
      end

      context 'with nested includes' do
        let(:params) { { includes: ['matches.team_1'] } }

        it 'applies eager loading for nested associations' do
          team1 = FactoryBot.create(:team, round: round1)
          team2 = FactoryBot.create(:team, round: round1)
          match = FactoryBot.create(:match, round: round1, team_1: team1, team_2: team2)
          result = query_result.to_a
          round = result.find { |r| r.id == round1.id }
          expect(round.association(:matches).loaded?).to be true
          expect(round.matches.first.association(:team_1).loaded?).to be true
        end
      end

      context 'with multiple includes' do
        let(:params) { { includes: ['championship', 'matches'] } }

        it 'applies eager loading for multiple associations' do
          result = query_result.to_a
          expect(result.first.association(:championship).loaded?).to be true
          expect(result.first.association(:matches).loaded?).to be true
        end
      end

      context 'with empty includes array' do
        let(:params) { { includes: [] } }

        it 'does not apply includes' do
          result = query_result.to_a
          expect(result.first.association(:championship).loaded?).to be false
        end
      end
    end

    context 'with pagination' do
      context 'with page and per_page' do
        let(:params) { { relation: Round.where(id: [round1.id, round2.id, round3.id]), page: 1, per_page: 2 } }

        it 'returns paginated results' do
          result = query_result.to_a
          expect(result.length).to eq(2)
        end

        it 'returns first page ordered by round_date descending' do
          result = query_result.to_a
          expect(result.length).to eq(2)
          # Verify ordering: round2 (2025-01-15) should be first, round3 (2025-01-10) should be second
          expect(result.map(&:round_date)).to eq([Date.new(2025, 1, 15), Date.new(2025, 1, 10)])
          expect(result.map(&:id)).to eq([round2.id, round3.id])
        end
      end

      context 'with second page' do
        let(:params) { { relation: Round.where(id: [round1.id, round2.id, round3.id]), page: 2, per_page: 2 } }

        it 'returns second page' do
          result = query_result.to_a
          # Should return the remaining round (round1 with date 2025-01-01)
          expect(result.length).to eq(1)
          expect(result.first.round_date).to eq(Date.new(2025, 1, 1))
          expect(result.first.id).to eq(round1.id)
        end
      end

      context 'with page but no per_page' do
        let(:params) { { page: 1 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          # Should return all rounds (no pagination applied)
          round_ids = result.map(&:id)
          expect(round_ids).to include(round1.id, round2.id, round3.id)
        end
      end

      context 'with per_page but no page' do
        let(:params) { { per_page: 2 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          # Should return all rounds (no pagination applied)
          round_ids = result.map(&:id)
          expect(round_ids).to include(round1.id, round2.id, round3.id)
        end
      end
    end

    context 'with includes and pagination combined' do
      let(:params) { { includes: ['championship'], page: 1, per_page: 2 } }

      it 'applies both includes and pagination' do
        result = query_result.to_a
        expect(result.length).to eq(2)
        expect(result.first.association(:championship).loaded?).to be true
      end
    end

    context 'with custom relation, includes, and pagination' do
      let(:params) do
        {
          relation: Round.where(id: [round1.id, round2.id, round3.id]),
          includes: ['championship'],
          page: 1,
          per_page: 1
        }
      end

      it 'applies all filters correctly' do
        result = query_result.to_a
        expect(result.length).to eq(1)
        expect(result.first.round_date).to eq(Date.new(2025, 1, 15))
        expect(result.first.association(:championship).loaded?).to be true
      end
    end
  end
end
