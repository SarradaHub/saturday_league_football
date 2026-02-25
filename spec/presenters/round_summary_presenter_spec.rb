# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoundSummaryPresenter do
  subject(:presenter) { described_class.new(round) }

  let(:championship) { FactoryBot.create(:championship) }
  let(:round) { FactoryBot.create(:round, championship: championship, name: 'Round 1') }

  describe '#as_json' do
    let(:json) { presenter.as_json }

    it 'returns only summary keys' do
      expect(json.keys).to match_array(%i[id name round_date championship_id matches_count players_count created_at])
    end

    it 'includes id and name' do
      expect(json[:id]).to eq(round.id)
      expect(json[:name]).to eq('Round 1')
    end

    it 'does not include matches, players or teams' do
      expect(json).not_to have_key(:matches)
      expect(json).not_to have_key(:players)
      expect(json).not_to have_key(:teams)
    end
  end
end
