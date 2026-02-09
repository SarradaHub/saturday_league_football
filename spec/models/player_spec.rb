# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Player, type: :model do
  subject { FactoryBot.create(:player) }

  it { should have_many :player_teams }
  it { should have_many(:teams).through(:player_teams) }
  it { should have_many :player_stats }
  it { should be_valid }

  describe 'name validation' do
    it 'is valid with first_name only' do
      player = FactoryBot.build(:player, first_name: 'John', last_name: nil, nickname: nil)
      expect(player).to be_valid
    end

    it 'is valid with last_name only' do
      player = FactoryBot.build(:player, first_name: nil, last_name: 'Doe', nickname: nil)
      expect(player).to be_valid
    end

    it 'is valid with nickname only' do
      player = FactoryBot.build(:player, first_name: nil, last_name: nil, nickname: 'JD')
      expect(player).to be_valid
    end

    it 'is invalid when all name parts are blank' do
      player = FactoryBot.build(:player, first_name: nil, last_name: nil, nickname: nil)
      expect(player).not_to be_valid
      expect(player.errors[:base]).to include(I18n.t('activerecord.errors.models.player.name_required'))
    end
  end
end
