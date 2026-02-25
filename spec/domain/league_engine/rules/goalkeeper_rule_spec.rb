 # frozen_string_literal: true

 require 'rails_helper'

 RSpec.describe LeagueEngine::Rules::GoalkeeperRule do
  describe '.valid_configuration?' do
    it 'returns true when player is only line player' do
      rows = [
        { player_id: 1, team_id: 10, was_goalkeeper: false, goals: 2, assists: 1 }
      ]

      expect(described_class.valid_configuration?(rows)).to be(true)
    end

    it 'returns true when player is only goalkeeper' do
      rows = [
        { player_id: 1, team_id: 10, was_goalkeeper: true, goals: 0, assists: 0 }
      ]

      expect(described_class.valid_configuration?(rows)).to be(true)
    end

    it 'returns false when player is goalkeeper and line player in same payload' do
      rows = [
        { player_id: 1, team_id: 10, was_goalkeeper: false, goals: 1, assists: 0 },
        { player_id: 1, team_id: 11, was_goalkeeper: true, goals: 0, assists: 0 }
      ]

      expect(described_class.valid_configuration?(rows)).to be(false)
    end

    it 'handles string keys and string booleans' do
      rows = [
        { 'player_id' => 1, 'team_id' => 10, 'was_goalkeeper' => 'false' },
        { 'player_id' => 1, 'team_id' => 11, 'was_goalkeeper' => 'true' }
      ]

      expect(described_class.valid_configuration?(rows)).to be(false)
    end

    it 'ignores rows without was_goalkeeper key for line player detection' do
      rows = [
        { player_id: 1, team_id: 10, goals: 1, assists: 0 },
        { player_id: 1, team_id: 11, was_goalkeeper: true }
      ]

      expect(described_class.valid_configuration?(rows)).to be(true)
    end
  end
 end
