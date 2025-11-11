# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Player, type: :model do
  subject { FactoryBot.create(:player) }

  it { should validate_presence_of :name }
  it { should have_many :player_teams }
  it { should have_many(:teams).through(:player_teams) }
  it { should have_many :player_stats }
  it { should be_valid }
end
