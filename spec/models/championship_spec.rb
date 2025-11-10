# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Championship, type: :model do
  subject { FactoryBot.build(:championship) }

  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_numericality_of(:min_players_per_team).only_integer.is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:max_players_per_team).only_integer.is_greater_than(0) }
  it { is_expected.to have_many :rounds }

  it 'is invalid when max players is less than the minimum' do
    subject.min_players_per_team = 6
    subject.max_players_per_team = 5

    expect(subject).not_to be_valid
    expect(subject.errors[:max_players_per_team]).to include(/greater than or equal to/i)
  end
end
