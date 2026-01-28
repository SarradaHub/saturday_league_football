# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::SyncFromIdentityService do
  describe '.call' do
    let(:identity_user_data) do
      {
        'id' => 'external-123',
        'email' => 'user@example.com',
        'is_admin' => true
      }
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect do
          described_class.call(identity_user_data)
        end.to change(User, :count).by(1)
      end

      it 'sets the correct attributes' do
        user = described_class.call(identity_user_data)
        expect(user.external_id).to eq('external-123')
        expect(user.email).to eq('user@example.com')
        expect(user.is_admin).to be true
      end
    end

    context 'when user already exists' do
      let!(:existing_user) { create(:user, external_id: 'external-123', email: 'old@example.com', is_admin: false) }

      it 'does not create a new user' do
        expect do
          described_class.call(identity_user_data)
        end.not_to change(User, :count)
      end

      it 'updates the user attributes' do
        user = described_class.call(identity_user_data)
        expect(user.email).to eq('user@example.com')
        expect(user.is_admin).to be true
      end
    end

    context 'when identity_user_data is nil' do
      it 'returns nil' do
        expect(described_class.call(nil)).to be_nil
      end
    end

    context 'when identity_user_data has no id' do
      it 'returns nil' do
        expect(described_class.call({ 'email' => 'test@example.com' })).to be_nil
      end
    end

    context 'when extracting admin flag from role' do
      let(:identity_user_data) do
        {
          'id' => 'external-123',
          'email' => 'user@example.com',
          'role' => 'admin'
        }
      end

      it 'sets is_admin to true' do
        user = described_class.call(identity_user_data)
        expect(user.is_admin).to be true
      end
    end
  end
end
