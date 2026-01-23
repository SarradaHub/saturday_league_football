# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerSerializer do
  describe '#as_json' do
    subject(:serializer) { described_class.new(player) }

    let(:player) { FactoryBot.create(:player, name: 'John Doe') }

    it 'serializes id and name' do
      json = serializer.as_json

      expect(json).to be_a(Hash)
      expect(json[:id]).to eq(player.id)
      expect(json[:name]).to eq('John Doe')
    end

    context 'with minimal name' do
      let(:player) { FactoryBot.create(:player, name: 'A') }

      it 'serializes minimal name' do
        json = serializer.as_json
        expect(json[:name]).to eq('A')
      end
    end

    context 'with special characters in name' do
      let(:player) { FactoryBot.create(:player, name: "José O'Connor-Smith") }

      it 'serializes special characters correctly' do
        json = serializer.as_json
        expect(json[:name]).to eq("José O'Connor-Smith")
      end
    end

    context 'with unicode characters' do
      let(:player) { FactoryBot.create(:player, name: 'Jürgen Müller') }

      it 'serializes unicode characters correctly' do
        json = serializer.as_json
        expect(json[:name]).to eq('Jürgen Müller')
      end
    end
  end
end
