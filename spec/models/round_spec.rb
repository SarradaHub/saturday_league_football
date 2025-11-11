# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Round, type: :model do
  subject { FactoryBot.create(:round, :with_championship) }

  it { should belong_to :championship }
  it { should have_many :matches }
  it { should validate_presence_of :name }
  it { should validate_presence_of :round_date }
  it { should be_valid }
end
