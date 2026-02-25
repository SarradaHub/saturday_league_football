# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerSerializer do
  describe '#as_json' do
    subject(:serializer) { described_class.new(player) }

    let(:player) { FactoryBot.create(:player, first_name: 'John', last_name: 'Doe') }

    it 'serializes id and display_name' do
      json = serializer.as_json

      expect(json).to be_a(Hash)
      expect(json[:id]).to eq(player.id)
      expect(json[:display_name]).to eq('John Doe')
    end

    context 'with minimal name' do
      let(:player) { FactoryBot.create(:player, first_name: 'A', last_name: nil) }

      it 'serializes minimal display_name' do
        json = serializer.as_json
        expect(json[:display_name]).to eq('A')
      end
    end

    context 'with special characters in name' do
      let(:player) { FactoryBot.create(:player, first_name: "José", last_name: "O'Connor-Smith") }

      it 'serializes special characters correctly' do
        json = serializer.as_json
        expect(json[:display_name]).to eq("José O'Connor-Smith")
      end
    end

    context 'with unicode characters' do
      let(:player) { FactoryBot.create(:player, first_name: 'Jürgen', last_name: 'Müller') }

      it 'serializes unicode characters correctly' do
        json = serializer.as_json
        expect(json[:display_name]).to eq('Jürgen Müller')
      end
    end
  end
end
