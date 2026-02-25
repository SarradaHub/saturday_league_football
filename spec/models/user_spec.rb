# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:championships).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_uniqueness_of(:external_id).allow_nil }
  end

  describe 'scopes' do
    describe '.admin' do
      let!(:admin_user) { create(:user, is_admin: true) }
      let!(:regular_user) { create(:user, is_admin: false) }

      it 'returns only admin users' do
        expect(described_class.admin).to include(admin_user)
        expect(described_class.admin).not_to include(regular_user)
      end
    end
  end

  describe '#admin?' do
    it 'returns true when user is admin' do
      user = build(:user, is_admin: true)
      expect(user.admin?).to be true
    end

    it 'returns false when user is not admin' do
      user = build(:user, is_admin: false)
      expect(user.admin?).to be false
    end
  end
end
