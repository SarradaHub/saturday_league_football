# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Matches::CollectionQuery do
  describe '.call' do
    subject(:query_result) { described_class.new(**params).call }

    let(:round) { FactoryBot.create(:round, :with_championship) }
    let(:team1) { FactoryBot.create(:team, round: round) }
    let(:team2) { FactoryBot.create(:team, round: round) }
    let(:team3) { FactoryBot.create(:team, round: round) }
    let(:team4) { FactoryBot.create(:team, round: round) }

    let!(:match1) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2, created_at: 3.days.ago) }
    let!(:match2) { FactoryBot.create(:match, round: round, team_1: team3, team_2: team4, created_at: 1.day.ago) }
    let!(:match3) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team3, created_at: 2.days.ago) }

    let(:params) { {} }

    context 'with default parameters' do
      it 'returns all matches ordered by created_at descending' do
        result = query_result.to_a
        match_ids = result.map(&:id)
        expect(match_ids).to include(match1.id, match2.id, match3.id)
        # Verify ordering: most recent first
        our_matches = result.select { |m| [match1.id, match2.id, match3.id].include?(m.id) }
        expect(our_matches.map(&:id)).to eq([match2.id, match3.id, match1.id])
      end

      it 'returns ActiveRecord::Relation' do
        expect(query_result).to be_a(ActiveRecord::Relation)
      end
    end

    context 'with custom relation' do
      let(:params) { { relation: Match.where(id: [match1.id, match2.id]) } }

      it 'filters by custom relation' do
        result = query_result.to_a
        expect(result.length).to eq(2)
        expect(result.map(&:id)).to contain_exactly(match1.id, match2.id)
      end

      it 'still orders by created_at descending' do
        result = query_result.to_a
        expect(result.map(&:id)).to eq([match2.id, match1.id])
      end
    end

    context 'with includes' do
      context 'with simple includes' do
        let(:params) { { includes: ['round'] } }

        it 'applies eager loading for round' do
          result = query_result.to_a
          expect(result.first.association(:round).loaded?).to be true
        end

        it 'returns matches with loaded associations' do
          result = query_result.to_a
          match = result.find { |m| [match1.id, match2.id, match3.id].include?(m.id) }
          expect(match).to be_present
          expect(match.association(:round).loaded?).to be true
          expect(match.round).to eq(round)
        end
      end

      context 'with nested includes' do
        let(:params) { { includes: ['round.championship'] } }

        it 'applies eager loading for nested associations' do
          result = query_result.to_a
          match = result.find { |m| [match1.id, match2.id, match3.id].include?(m.id) }
          expect(match.association(:round).loaded?).to be true
          expect(match.round.association(:championship).loaded?).to be true
        end
      end

      context 'with multiple includes' do
        let(:params) { { includes: ['round', 'team_1'] } }

        it 'applies eager loading for multiple associations' do
          result = query_result.to_a
          expect(result.first.association(:round).loaded?).to be true
          expect(result.first.association(:team_1).loaded?).to be true
        end
      end

      context 'with empty includes array' do
        let(:params) { { includes: [] } }

        it 'does not apply includes' do
          result = query_result.to_a
          expect(result.first.association(:round).loaded?).to be false
        end
      end
    end

    context 'with pagination' do
      context 'with page and per_page' do
        let(:params) { { relation: Match.where(id: [match1.id, match2.id, match3.id]), page: 1, per_page: 2 } }

        it 'returns paginated results' do
          result = query_result.to_a
          expect(result.length).to eq(2)
        end

        it 'returns first page ordered by created_at descending' do
          result = query_result.to_a
          expect(result.length).to eq(2)
          # Most recent first: match2 (1 day ago), match3 (2 days ago)
          expect(result.map(&:id)).to eq([match2.id, match3.id])
        end
      end

      context 'with second page' do
        let(:params) { { relation: Match.where(id: [match1.id, match2.id, match3.id]), page: 2, per_page: 2 } }

        it 'returns second page' do
          result = query_result.to_a
          expect(result.length).to eq(1)
          expect(result.first.id).to eq(match1.id)
        end
      end

      context 'with page but no per_page' do
        let(:params) { { page: 1 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          match_ids = result.map(&:id)
          expect(match_ids).to include(match1.id, match2.id, match3.id)
        end
      end

      context 'with per_page but no page' do
        let(:params) { { per_page: 2 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          match_ids = result.map(&:id)
          expect(match_ids).to include(match1.id, match2.id, match3.id)
        end
      end
    end

    context 'with includes and pagination combined' do
      let(:params) { { includes: ['round'], page: 1, per_page: 2 } }

      it 'applies both includes and pagination' do
        result = query_result.to_a
        expect(result.length).to eq(2)
        expect(result.first.association(:round).loaded?).to be true
      end
    end

    context 'with custom relation, includes, and pagination' do
      let(:params) do
        {
          relation: Match.where(id: [match1.id, match2.id, match3.id]),
          includes: ['round'],
          page: 1,
          per_page: 1
        }
      end

      it 'applies all filters correctly' do
        result = query_result.to_a
        expect(result.length).to eq(1)
        expect(result.first.id).to eq(match2.id)
        expect(result.first.association(:round).loaded?).to be true
      end
    end
  end
end
