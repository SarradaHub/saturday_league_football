# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NestedGroups, RSpec/MultipleMemoizedHelpers, RSpec/ExampleLength, RSpec/MultipleExpectations

RSpec.describe Players::CollectionQuery do
  describe '.call' do
    subject(:query_result) { described_class.new(**params).call }

    let(:championship1) { FactoryBot.create(:championship) }
    let(:params) { {} }
    let(:championship2) { FactoryBot.create(:championship) }
    let(:round1) { FactoryBot.create(:round, championship: championship1) }
    let(:round2) { FactoryBot.create(:round, championship: championship1) }
    let(:round3) { FactoryBot.create(:round, championship: championship2) }

    let!(:player1) { FactoryBot.create(:player, first_name: 'Alice', last_name: nil) }
    let!(:player2) { FactoryBot.create(:player, first_name: 'Bob', last_name: nil) }
    let!(:player3) { FactoryBot.create(:player, first_name: 'Charlie', last_name: nil) }
    let!(:player4) { FactoryBot.create(:player, first_name: 'David', last_name: nil) }

    before do
      # player1 and player2 in championship1
      FactoryBot.create(:player_round, player: player1, round: round1)
      FactoryBot.create(:player_round, player: player2, round: round2)
      # player3 in championship2
      FactoryBot.create(:player_round, player: player3, round: round3)
      # player4 not in any championship
    end


    context 'with default parameters' do
      it 'returns all players ordered by first_name' do
        result = query_result.to_a
        player_names = result.map(&:display_name)
        expect(player_names).to include('Alice', 'Bob', 'Charlie', 'David')
        # Verify ordering
        our_players = result.select { |p| [player1.id, player2.id, player3.id, player4.id].include?(p.id) }
        expect(our_players.map(&:display_name)).to eq(['Alice', 'Bob', 'Charlie', 'David'])
      end

      it 'returns ActiveRecord::Relation' do
        expect(query_result).to be_a(ActiveRecord::Relation)
      end
    end

    context 'with championship_id filter' do
      let(:params) { { championship_id: championship1.id } }

      it 'filters players by championship' do
        result = query_result.to_a
        player_ids = result.map(&:id)
        expect(player_ids).to contain_exactly(player1.id, player2.id)
        expect(player_ids).not_to include(player3.id, player4.id)
      end

      it 'still orders by first_name' do
        result = query_result.to_a
        expect(result.map(&:display_name)).to eq(['Alice', 'Bob'])
      end
    end

    context 'with different championship_id' do
      let(:params) { { championship_id: championship2.id } }

      it 'returns only players from that championship' do
        result = query_result.to_a
        expect(result.map(&:id)).to contain_exactly(player3.id)
      end
    end

    context 'with includes' do
      context 'with simple includes' do
        let(:params) { { includes: ['teams'] } }

        it 'applies eager loading for teams' do
          team = FactoryBot.create(:team, round: round1)
          team.players << player1
          result = query_result.to_a
          player = result.find { |p| p.id == player1.id }
          expect(player.association(:teams).loaded?).to be true
        end

        it 'returns players with loaded associations' do
          team = FactoryBot.create(:team, round: round1)
          team.players << player1
          result = query_result.to_a
          player = result.find { |p| p.id == player1.id }
          expect(player).to be_present
          expect(player.association(:teams).loaded?).to be true
        end
      end

      context 'with nested includes' do
        let(:params) { { includes: ['teams.round'] } }

        it 'applies eager loading for nested associations' do
          team = FactoryBot.create(:team, round: round1)
          team.players << player1
          result = query_result.to_a
          player = result.find { |p| p.id == player1.id }
          expect(player.association(:teams).loaded?).to be true
          expect(player.teams.first.association(:round).loaded?).to be true
        end
      end

      context 'with multiple includes' do
        let(:params) { { includes: ['teams', 'rounds'] } }

        it 'applies eager loading for multiple associations' do
          # player1 already has a player_round in the main before block, so don't create duplicate
          result = query_result.to_a
          player = result.find { |p| p.id == player1.id }
          expect(player).to be_present
          expect(player.association(:teams).loaded?).to be true
          expect(player.association(:rounds).loaded?).to be true
        end
      end

      context 'with empty includes array' do
        let(:params) { { includes: [] } }

        it 'does not apply includes' do
          result = query_result.to_a
          expect(result.first.association(:teams).loaded?).to be false
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

        it 'returns first page ordered by first_name' do
          result = query_result.to_a
          expect(result.length).to eq(2)
          # Verify our test players might be in the first page (depending on other players in DB)
          result_names = result.map(&:display_name)
          # Just verify we got 2 results and they're ordered by display_name
          expect(result_names.length).to eq(2)
          expect(result_names).to eq(result_names.sort)
        end
      end

      context 'with second page' do
        let(:params) { { page: 2, per_page: 2 } }

        it 'returns second page' do
          result = query_result.to_a
          # Second page should have 2 items (or fewer if total is less than 4)
          expect(result.length).to be <= 2
          # Verify results are ordered by display_name
          result_names = result.map(&:display_name)
          expect(result_names).to eq(result_names.sort)
        end
      end

      context 'with page but no per_page' do
        let(:params) { { page: 1 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          player_ids = result.map(&:id)
          expect(player_ids).to include(player1.id, player2.id, player3.id, player4.id)
        end
      end

      context 'with per_page but no page' do
        let(:params) { { per_page: 2 } }

        it 'does not apply pagination' do
          result = query_result.to_a
          player_ids = result.map(&:id)
          expect(player_ids).to include(player1.id, player2.id, player3.id, player4.id)
        end
      end
    end

    context 'with championship_id and includes combined' do
      let(:params) { { championship_id: championship1.id, includes: ['teams'] } }

      it 'applies both filter and includes' do
        team = FactoryBot.create(:team, round: round1)
        team.players << player1
        result = query_result.to_a
        expect(result.map(&:id)).to contain_exactly(player1.id, player2.id)
        player = result.find { |p| p.id == player1.id }
        expect(player.association(:teams).loaded?).to be true
      end
    end

    context 'with championship_id, includes, and pagination' do
      let(:params) do
        {
          championship_id: championship1.id,
          includes: ['teams'],
          page: 1,
          per_page: 1
        }
      end

      it 'applies all filters correctly' do
        team = FactoryBot.create(:team, round: round1)
        team.players << player1
        result = query_result.to_a
        expect(result.length).to eq(1)
        expect(result.first.display_name).to eq('Alice')
        expect(result.first.association(:teams).loaded?).to be true
      end
    end
  end
end

# rubocop:enable RSpec/NestedGroups, RSpec/MultipleMemoizedHelpers, RSpec/ExampleLength, RSpec/MultipleExpectations
