# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchSummaryPresenter do
  subject(:presenter) { described_class.new(match) }

  let(:round) { FactoryBot.create(:round, championship: FactoryBot.create(:championship)) }
  let(:team1) { FactoryBot.create(:team, round: round, name: 'Team A') }
  let(:team2) { FactoryBot.create(:team, round: round, name: 'Team B') }
  let(:match) { FactoryBot.create(:match, round: round, team_1: team1, team_2: team2, name: 'A vs B') }

  describe '#as_json' do
    let(:json) { presenter.as_json }

    it 'returns only summary keys' do
      expected = %i[id name round_id team_1_id team_2_id winning_team_id draw team_1_goals team_2_goals team_1_name team_2_name created_at]
      expect(json.keys).to match_array(expected)
    end

    it 'includes id, name and team names' do
      expect(json[:id]).to eq(match.id)
      expect(json[:name]).to eq('A vs B')
      expect(json[:team_1_name]).to eq('Team A')
      expect(json[:team_2_name]).to eq('Team B')
    end

    it 'does not include full team objects or statistics' do
      expect(json).not_to have_key(:team_1_players)
      expect(json).not_to have_key(:statistics)
    end
  end
end
