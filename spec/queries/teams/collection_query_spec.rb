# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teams::CollectionQuery do
  describe '.call' do
    subject(:query_result) { described_class.new(**params).call }

    let(:round) { FactoryBot.create(:round, :with_championship) }
    let!(:team1) { FactoryBot.create(:team, round: round, name: 'Team A') }
    let!(:team2) { FactoryBot.create(:team, round: round, name: 'Team B') }
    let!(:team3) { FactoryBot.create(:team, round: round, name: 'Team C') }
    let(:params) { {} }

    context 'with default parameters' do
      it 'returns all teams ordered by name' do
        result = query_result.to_a
        # Check that our created teams are in the result
        team_names = result.map(&:name)
        expect(team_names).to include('Team A', 'Team B', 'Team C')
        # Verify ordering for our teams
        our_teams = result.select { |t| ['Team A', 'Team B', 'Team C'].include?(t.name) }
        expect(our_teams.map(&:name)).to eq(['Team A', 'Team B', 'Team C'])
      end

      it 'returns ActiveRecord::Relation' do
        expect(query_result).to be_a(ActiveRecord::Relation)
      end
    end

    context 'with custom relation' do
      let(:params) { { relation: Team.where(id: [team1.id, team2.id]) } }

      it 'filters by custom relation' do
        result = query_result.to_a
        expect(result.length).to eq(2)
        expect(result.map(&:id)).to contain_exactly(team1.id, team2.id)
      end

      it 'still orders by name' do
        result = query_result.to_a
        expect(result.map(&:name)).to eq(['Team A', 'Team B'])
      end
    end

    context 'with includes' do
      context 'with simple includes' do
        let(:params) { { includes: ['round'] } }

        it 'applies eager loading for round' do
          result = query_result.to_a
          expect(result.first.association(:round).loaded?).to be true
        end

        it 'returns teams with loaded associations' do
          result = query_result.to_a
          expect(result.first.round).to eq(round)
        end
      end

      context 'with nested includes' do
        let(:params) { { includes: ['round.championship'] } }

        it 'applies eager loading for nested associations' do
          result = query_result.to_a
          expect(result.first.association(:round).loaded?).to be true
          expect(result.first.round.association(:championship).loaded?).to be true
        end
      end

      context 'with multiple includes' do
        let(:params) { { includes: ['round', 'player_teams'] } }

        it 'applies eager loading for multiple associations' do
          result = query_result.to_a
          expect(result.first.association(:round).loaded?).to be true
          expect(result.first.association(:player_teams).loaded?).to be true
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
        let(:params) { { page: 1, per_page: 2 } }

        it 'returns paginated results' do
          result = query_result.to_a
          expect(result.length).to eq(2)
        end

        it 'returns first page ordered by name' do
          result = query_result.to_a
          expect(result.length).to eq(2)
          # Verify our teams are in the result (may be mixed with other teams)
          team_names = result.map(&:name)
          expect(team_names).to include('Team A', 'Team B')
        end
      end

      context 'with second page' do
        let(:params) { { page: 2, per_page: 2 } }

        it 'returns second page' do
          result = query_result.to_a
          # Should return items from second page (may include other teams from DB)
          expect(result.length).to eq(2)
          # Verify our Team C is in the result (it should be on page 2 if sorted by name)
          team_names = result.map(&:name)
          expect(team_names).to include('Team C')
        end
      end

      context 'with page but no per_page' do
        let(:params) { { page: 1 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          # Should return all teams (no pagination applied)
          team_names = result.map(&:name)
          expect(team_names).to include('Team A', 'Team B', 'Team C')
        end
      end

      context 'with per_page but no page' do
        let(:params) { { per_page: 2 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          # Should return all teams (no pagination applied)
          team_names = result.map(&:name)
          expect(team_names).to include('Team A', 'Team B', 'Team C')
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
          relation: Team.where(id: [team1.id, team2.id, team3.id]),
          includes: ['round'],
          page: 1,
          per_page: 1
        }
      end

      it 'applies all filters correctly' do
        result = query_result.to_a
        expect(result.length).to eq(1)
        expect(result.first.name).to eq('Team A')
        expect(result.first.association(:round).loaded?).to be true
      end
    end
  end
end
