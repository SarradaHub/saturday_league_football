# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Match, type: :model do
  subject { FactoryBot.create(:match, :with_round, :with_team_1, :with_team_2, :with_winning_team) }

  it { should belong_to :round }
  it { should belong_to :team_1 }
  it { should belong_to :team_2 }
  it { should belong_to(:winning_team).optional }
  it { should validate_presence_of :name }
  it { should be_valid }
end
