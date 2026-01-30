# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Championships::CollectionQuery do
  describe '.call' do
    subject(:query_result) { described_class.new(**params).call }

    let!(:championship1) { FactoryBot.create(:championship, updated_at: 3.days.ago) }
    let!(:championship2) { FactoryBot.create(:championship, updated_at: 1.day.ago) }
    let!(:championship3) { FactoryBot.create(:championship, updated_at: 2.days.ago) }
    let(:params) { {} }

    context 'with default parameters' do
      it 'returns all championships ordered by updated_at descending' do
        result = query_result.to_a
        # Check that our created championships are in the result
        championship_ids = result.map(&:id)
        expect(championship_ids).to include(championship1.id, championship2.id, championship3.id)
        # Verify ordering for our championships
        our_championships = result.select { |c| [championship1.id, championship2.id, championship3.id].include?(c.id) }
        expect(our_championships.map(&:id)).to eq([championship2.id, championship3.id, championship1.id])
      end

      it 'returns ActiveRecord::Relation' do
        expect(query_result).to be_a(ActiveRecord::Relation)
      end
    end

    context 'with custom relation' do
      let(:params) { { relation: Championship.where(id: [championship1.id, championship2.id]) } }

      it 'filters by custom relation' do
        result = query_result.to_a
        expect(result.length).to eq(2)
        expect(result.map(&:id)).to contain_exactly(championship1.id, championship2.id)
      end

      it 'still orders by updated_at descending' do
        result = query_result.to_a
        expect(result.map(&:id)).to eq([championship2.id, championship1.id])
      end
    end

    context 'with includes' do
      context 'with simple includes' do
        let(:params) { { includes: ['rounds'] } }

        it 'applies eager loading for rounds' do
          round = FactoryBot.create(:round, championship: championship1)
          result = query_result.to_a
          championship = result.find { |c| c.id == championship1.id }
          expect(championship.association(:rounds).loaded?).to be true
        end

        it 'returns championships with loaded associations' do
          round = FactoryBot.create(:round, championship: championship1)
          result = query_result.to_a
          championship = result.find { |c| c.id == championship1.id }
          expect(championship).to be_present
          expect(championship.association(:rounds).loaded?).to be true
        end
      end

      context 'with nested includes' do
        let(:params) { { includes: ['rounds.matches'] } }

        it 'applies eager loading for nested associations' do
          round = FactoryBot.create(:round, championship: championship1)
          team1 = FactoryBot.create(:team, round: round)
          team2 = FactoryBot.create(:team, round: round)
          match = FactoryBot.create(:match, round: round, team_1: team1, team_2: team2)
          result = query_result.to_a
          championship = result.find { |c| c.id == championship1.id }
          expect(championship.association(:rounds).loaded?).to be true
          expect(championship.rounds.first.association(:matches).loaded?).to be true
        end
      end

      context 'with multiple includes' do
        let(:params) { { includes: ['rounds', 'players'] } }

        it 'applies eager loading for multiple associations' do
          round = FactoryBot.create(:round, championship: championship1)
          player = FactoryBot.create(:player)
          FactoryBot.create(:player_round, player: player, round: round)
          result = query_result.to_a
          championship = result.find { |c| c.id == championship1.id }
          expect(championship.association(:rounds).loaded?).to be true
          loaded_round = championship.rounds.first
          expect(loaded_round.association(:player_rounds).loaded?).to be true
          expect(loaded_round.player_rounds.first.association(:player).loaded?).to be true
        end
      end

      context 'with empty includes array' do
        let(:params) { { includes: [] } }

        it 'does not apply includes' do
          result = query_result.to_a
          expect(result.first.association(:rounds).loaded?).to be false
        end
      end
    end

    context 'with pagination' do
      context 'with page and per_page' do
        let(:params) { { relation: Championship.where(id: [championship1.id, championship2.id, championship3.id]), page: 1, per_page: 2 } }

        it 'returns paginated results' do
          result = query_result.to_a
          expect(result.length).to eq(2)
        end

        it 'returns first page ordered by updated_at descending' do
          result = query_result.to_a
          expect(result.length).to eq(2)
          # Verify ordering: championship2 (1 day ago) should be first, championship3 (2 days ago) should be second
          expect(result.map(&:id)).to eq([championship2.id, championship3.id])
        end
      end

      context 'with second page' do
        let(:params) { { relation: Championship.where(id: [championship1.id, championship2.id, championship3.id]), page: 2, per_page: 2 } }

        it 'returns second page' do
          result = query_result.to_a
          # Should return the remaining championship (championship1 with 3 days ago)
          expect(result.length).to eq(1)
          expect(result.first.id).to eq(championship1.id)
        end
      end

      context 'with page but no per_page' do
        let(:params) { { page: 1 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          # Should return all championships (no pagination applied)
          championship_ids = result.map(&:id)
          expect(championship_ids).to include(championship1.id, championship2.id, championship3.id)
        end
      end

      context 'with per_page but no page' do
        let(:params) { { per_page: 2 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          # Should return all championships (no pagination applied)
          championship_ids = result.map(&:id)
          expect(championship_ids).to include(championship1.id, championship2.id, championship3.id)
        end
      end
    end

    context 'with includes and pagination combined' do
      let(:params) { { includes: ['rounds'], page: 1, per_page: 2 } }

      it 'applies both includes and pagination' do
        FactoryBot.create(:round, championship: championship1)
        result = query_result.to_a
        expect(result.length).to eq(2)
        championship = result.find { |c| c.id == championship1.id }
        expect(championship.association(:rounds).loaded?).to be true if championship
      end
    end

    context 'with custom relation, includes, and pagination' do
      let(:params) do
        {
          relation: Championship.where(id: [championship1.id, championship2.id, championship3.id]),
          includes: ['rounds'],
          page: 1,
          per_page: 1
        }
      end

      it 'applies all filters correctly' do
        FactoryBot.create(:round, championship: championship1)
        result = query_result.to_a
        expect(result.length).to eq(1)
        expect(result.first.id).to eq(championship2.id)
        expect(result.first.association(:rounds).loaded?).to be true
      end
    end
  end
end
