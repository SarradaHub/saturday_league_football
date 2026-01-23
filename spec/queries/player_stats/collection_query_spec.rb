# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerStats::CollectionQuery do
  describe '.call' do
    subject(:query_result) { described_class.new(**params).call }

    let(:match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }
    let(:player1) { FactoryBot.create(:player) }
    let(:player2) { FactoryBot.create(:player) }
    let(:player3) { FactoryBot.create(:player) }
    let(:team1) { match.team_1 }
    let(:team2) { match.team_2 }
    let!(:stat1) { FactoryBot.create(:player_stat, player: player1, team: team1, match: match, goals: 2, assists: 1, own_goals: 0) }
    let!(:stat2) { FactoryBot.create(:player_stat, player: player2, team: team2, match: match, goals: 1, assists: 0, own_goals: 0) }
    let!(:stat3) { FactoryBot.create(:player_stat, player: player3, team: team1, match: match, goals: 3, assists: 2, own_goals: 0) }
    let(:params) { {} }

    context 'with default parameters' do
      it 'returns all player stats' do
        result = query_result.to_a
        # Check that our created stats are in the result
        stat_ids = result.map(&:id)
        expect(stat_ids).to include(stat1.id, stat2.id, stat3.id)
      end

      it 'returns ActiveRecord::Relation' do
        expect(query_result).to be_a(ActiveRecord::Relation)
      end
    end

    context 'with custom relation' do
      let(:params) { { relation: PlayerStat.where(id: [stat1.id, stat2.id]) } }

      it 'filters by custom relation' do
        result = query_result.to_a
        expect(result.length).to eq(2)
        expect(result.map(&:id)).to contain_exactly(stat1.id, stat2.id)
      end
    end

    context 'with includes' do
      context 'with simple includes' do
        let(:params) { { includes: ['player'] } }

        it 'applies eager loading for player' do
          result = query_result.to_a
          expect(result.first.association(:player).loaded?).to be true
        end

        it 'returns stats with loaded associations' do
          result = query_result.to_a
          # Find one of our created stats
          our_stat = result.find { |s| [stat1.id, stat2.id, stat3.id].include?(s.id) }
          expect(our_stat).to be_present
          expect(our_stat.association(:player).loaded?).to be true
          expect(our_stat.player).to be_present
        end
      end

      context 'with multiple simple includes' do
        let(:params) { { includes: ['player', 'team'] } }

        it 'applies eager loading for multiple associations' do
          result = query_result.to_a
          our_stat = result.find { |s| [stat1.id, stat2.id, stat3.id].include?(s.id) }
          expect(our_stat).to be_present
          expect(our_stat.association(:player).loaded?).to be true
          expect(our_stat.association(:team).loaded?).to be true
        end
      end

      context 'with nested includes' do
        let(:params) { { includes: ['player.teams'] } }

        it 'applies eager loading for nested associations' do
          # Associate player with teams
          team1.players << player1
          result = query_result.to_a
          stat = result.find { |s| s.id == stat1.id }
          expect(stat).to be_present
          expect(stat.association(:player).loaded?).to be true
          expect(stat.player.association(:teams).loaded?).to be true
        end
      end

      context 'with match nested includes' do
        let(:params) { { includes: ['match.round'] } }

        it 'applies eager loading for match.round' do
          result = query_result.to_a
          stat = result.find { |s| [stat1.id, stat2.id, stat3.id].include?(s.id) }
          expect(stat).to be_present
          expect(stat.association(:match).loaded?).to be true
          expect(stat.match.association(:round).loaded?).to be true
        end
      end

      context 'with empty includes array' do
        let(:params) { { includes: [] } }

        it 'does not apply includes' do
          result = query_result.to_a
          our_stat = result.find { |s| [stat1.id, stat2.id, stat3.id].include?(s.id) }
          expect(our_stat).to be_present
          expect(our_stat.association(:player).loaded?).to be false
        end
      end
    end

    context 'with pagination' do
      context 'with page and per_page' do
        let(:params) { { relation: PlayerStat.where(id: [stat1.id, stat2.id, stat3.id]), page: 1, per_page: 2 } }

        it 'returns paginated results' do
          result = query_result.to_a
          expect(result.length).to eq(2)
        end
      end

      context 'with second page' do
        let(:params) { { relation: PlayerStat.where(id: [stat1.id, stat2.id, stat3.id]), page: 2, per_page: 2 } }

        it 'returns second page' do
          result = query_result.to_a
          # Should return the remaining stat
          expect(result.length).to eq(1)
          expect(result.first.id).to be_in([stat1.id, stat2.id, stat3.id])
        end
      end

      context 'with page but no per_page' do
        let(:params) { { page: 1 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          # Should return all stats (no pagination applied)
          stat_ids = result.map(&:id)
          expect(stat_ids).to include(stat1.id, stat2.id, stat3.id)
        end
      end

      context 'with per_page but no page' do
        let(:params) { { per_page: 2 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          # Should return all stats (no pagination applied)
          stat_ids = result.map(&:id)
          expect(stat_ids).to include(stat1.id, stat2.id, stat3.id)
        end
      end
    end

    context 'with includes and pagination combined' do
      let(:params) { { relation: PlayerStat.where(id: [stat1.id, stat2.id, stat3.id]), includes: ['player'], page: 1, per_page: 2 } }

      it 'applies both includes and pagination' do
        result = query_result.to_a
        expect(result.length).to eq(2)
        # Verify includes are applied - all results should have player association loaded
        result.each do |stat|
          expect(stat.association(:player).loaded?).to be true
        end
      end
    end

    context 'with custom relation, includes, and pagination' do
      let(:params) do
        {
          relation: PlayerStat.where(id: [stat1.id, stat2.id, stat3.id]),
          includes: ['player', 'team'],
          page: 1,
          per_page: 1
        }
      end

      it 'applies all filters correctly' do
        result = query_result.to_a
        expect(result.length).to eq(1)
        expect(result.first.id).to be_in([stat1.id, stat2.id, stat3.id])
        expect(result.first.association(:player).loaded?).to be true
        expect(result.first.association(:team).loaded?).to be true
      end
    end

    context 'with match_id filter' do
      let(:other_match) { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2) }
      let!(:other_stat) { FactoryBot.create(:player_stat, player: FactoryBot.create(:player), team: other_match.team_1, match: other_match) }
      let(:params) { { relation: PlayerStat.where(match_id: match.id) } }

      it 'filters by match_id correctly' do
        result = query_result.to_a
        result_ids = result.map(&:id)
        expect(result_ids).to include(stat1.id, stat2.id, stat3.id)
        expect(result_ids).not_to include(other_stat.id)
      end
    end

    context 'with team_id filter' do
      let(:params) { { relation: PlayerStat.where(team_id: team1.id) } }

      it 'filters by team_id correctly' do
        result = query_result.to_a
        result_ids = result.map(&:id)
        expect(result_ids).to include(stat1.id, stat3.id)
        expect(result_ids).not_to include(stat2.id)
      end
    end
  end
end
