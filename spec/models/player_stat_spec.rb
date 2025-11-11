# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerStat, type: :model do
  subject { FactoryBot.create(:player_stat, :with_player, :with_team, :with_match) }

  it { should belong_to :player }
  it { should belong_to :team }
  it { should belong_to :match }
  it { should validate_presence_of :goals }
  it { should validate_presence_of :assists }
  it { should validate_presence_of :own_goals }
  it { should be_valid }
  # it { should validate_inclusion_of(:was_goalkeeper).in_array([true, false]) }
end
