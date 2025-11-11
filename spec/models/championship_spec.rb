# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Championship, type: :model do
  subject { FactoryBot.create(:championship) }

  it { should validate_presence_of :name }
  it { should have_many :rounds }
  it { should be_valid }
end
