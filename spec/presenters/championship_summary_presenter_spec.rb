# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChampionshipSummaryPresenter do
  subject(:presenter) { described_class.new(championship) }

  let(:championship) { FactoryBot.create(:championship, name: 'Test Cup', min_players_per_team: 4, max_players_per_team: 6) }

  describe '#as_json' do
    let(:json) { presenter.as_json }

    it 'returns only summary keys' do
      expect(json.keys).to match_array(%i[id name min_players_per_team max_players_per_team rounds_count players_count created_at])
    end

    it 'includes id and name' do
      expect(json[:id]).to eq(championship.id)
      expect(json[:name]).to eq('Test Cup')
    end

    it 'includes rounds_count and players_count' do
      expect(json).to have_key(:rounds_count)
      expect(json).to have_key(:players_count)
    end

    it 'does not include rounds or players' do
      expect(json).not_to have_key(:rounds)
      expect(json).not_to have_key(:players)
    end
  end
end
