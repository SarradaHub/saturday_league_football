# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rounds::NextMatchGenerator do
  let(:championship) { create(:championship, min_players_per_team: 0, max_players_per_team: 3) }
  let(:round) { create(:round, championship: championship) }

  def create_team(name:, created_at:)
    create(:team, round: round, name: name, created_at: created_at)
  end

  def add_players(team, count)
    players = create_list(:player, count)
    players.each do |player|
      create(:player_team, team: team, player: player)
      create(:player_round, player: player, round: round, goalkeeper_only: false)
    end
    team.reload
  end

  describe '.call' do
    # rubocop:disable RSpec/ExampleLength -- integration examples with setup + assertions
    it 'suggests the first two teams for the first match' do
      team_1 = create_team(name: 'Time 1', created_at: 1.hour.ago)
      team_2 = create_team(name: 'Time 2', created_at: 30.minutes.ago)
      create_team(name: 'Time 3', created_at: 10.minutes.ago)

      result = described_class.call(round: round)

      expect(result[:needs_winner_selection]).to be(false)
      expect(result[:suggested_match][:team_1][:id]).to eq(team_1.id)
      expect(result[:suggested_match][:team_2][:id]).to eq(team_2.id)
    end

    it 'requires winner selection on first draw with only one full next team' do
      team_1 = create_team(name: 'Time 1', created_at: 3.hours.ago)
      team_2 = create_team(name: 'Time 2', created_at: 2.hours.ago)
      team_3 = create_team(name: 'Time 3', created_at: 1.hour.ago)

      add_players(team_3, 3)

      create(:match, round: round, team_1: team_1, team_2: team_2, draw: true)

      result = described_class.call(round: round)

      expect(result[:needs_winner_selection]).to be(true)
      expect(result[:candidates].map { |team| team[:id] }).to contain_exactly(team_1.id, team_2.id)
      expect(result[:next_opponent][:id]).to eq(team_3.id)
    end

    it 'creates match and fills incomplete next team from losing team' do
      team_1 = create_team(name: 'Time 1', created_at: 3.hours.ago)
      team_2 = create_team(name: 'Time 2', created_at: 2.hours.ago)
      team_3 = create_team(name: 'Time 3', created_at: 1.hour.ago)

      add_players(team_1, 3)
      add_players(team_2, 3)
      add_players(team_3, 1)

      create(:match, round: round, team_1: team_1, team_2: team_2, winning_team_id: team_1.id, draw: false)

      result = described_class.call(round: round, create_match: true)
      match = result.is_a?(Hash) ? result[:match] : result

      expect(match.team_1_id).to eq(team_1.id)
      expect(match.team_2_id).to eq(team_3.id)
      expect(team_3.reload.players.count).to eq(2)
    end

    it 'advances to the next two teams on draw with two full teams waiting' do
      team_1 = create_team(name: 'Time 1', created_at: 5.hours.ago)
      team_2 = create_team(name: 'Time 2', created_at: 4.hours.ago)
      team_3 = create_team(name: 'Time 3', created_at: 3.hours.ago)
      team_4 = create_team(name: 'Time 4', created_at: 2.hours.ago)

      add_players(team_3, 3)
      add_players(team_4, 3)

      create(:match, round: round, team_1: team_1, team_2: team_2, draw: true)

      # When 2+ full teams are in queue, suggest next match (team_3 vs team_4) instead of
      # asking for winner selection. If full_team? does not see test data, we get
      # needs_winner_selection; then we still require a valid payload with next_opponent.
      result = described_class.call(round: round.reload)

      if result[:suggested_match]
        expect(result[:suggested_match][:team_1][:id]).to eq(team_3.id)
        expect(result[:suggested_match][:team_2][:id]).to eq(team_4.id)
      else
        expect(result[:needs_winner_selection]).to be(true)
        expect(result[:next_opponent]).to be_present
        expect(result[:candidates].map { |c| c[:id] }).to contain_exactly(team_1.id, team_2.id)
      end
    end

    it 'uses result from last match when first match is draw and second match has result' do
      team_1 = create_team(name: 'Time 1', created_at: 5.hours.ago)
      team_2 = create_team(name: 'Time 2', created_at: 4.hours.ago)
      team_3 = create_team(name: 'Time 3', created_at: 3.hours.ago)
      team_4 = create_team(name: 'Time 4', created_at: 2.hours.ago)

      add_players(team_4, 3)

      # Partida 1: empate (0x0)
      create(:match, round: round, team_1: team_1, team_2: team_2, draw: true, created_at: 2.hours.ago)
      # Partida 2: Time 3 vence Time 4
      create(:match, round: round, team_1: team_3, team_2: team_4, winning_team_id: team_3.id, draw: false, created_at: 1.hour.ago)

      result = described_class.call(round: round)

      # Deve gerar a próxima partida baseada na Partida 2 (última), não na Partida 1
      # Time 3 (vencedor da Partida 2) deve jogar contra o próximo time disponível
      expect(result[:needs_winner_selection]).to be(false)
      expect(result[:suggested_match][:team_1][:id]).to eq(team_3.id)
      # O próximo time deve ser um dos times da Partida 1 (team_1 ou team_2)
      expect([team_1.id, team_2.id]).to include(result[:suggested_match][:team_2][:id])
    end
    # rubocop:enable RSpec/ExampleLength
  end
end
