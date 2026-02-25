# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerSummaryPresenter do
  subject(:presenter) { described_class.new(player) }

  let(:player) { FactoryBot.create(:player, first_name: 'John', last_name: 'Doe') }

  describe '#as_json' do
    let(:json) { presenter.as_json }

    it 'returns only summary keys' do
      expect(json.keys).to match_array(%i[id display_name total_goals total_assists total_own_goals total_matches created_at])
    end

    it 'includes id and display_name' do
      expect(json[:id]).to eq(player.id)
      expect(json[:display_name]).to eq(player.display_name)
    end

    it 'does not include rounds or player_stats' do
      expect(json).not_to have_key(:rounds)
      expect(json).not_to have_key(:player_stats)
    end
  end
end
