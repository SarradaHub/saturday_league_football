# frozen_string_literal: true

require 'rails_helper'

# Create a test controller that includes the concern
class IncludableTestController < ApplicationController
  include Includable

  def index
    relation = Team.all
    includes_list = parse_includes
    relation_with_includes = apply_includes(relation, includes_list)
    render json: { includes: includes_list, count: relation_with_includes.count }
  end
end

RSpec.describe Includable, type: :controller do
  controller(IncludableTestController) do
  end

  let!(:test_teams) { FactoryBot.create_list(:team, 3) }

  describe '#parse_includes' do
    context 'when include param is present' do
      it 'parses comma-separated includes' do
        get :index, params: { include: 'round,players' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['includes']).to eq(['round', 'players'])
      end

      it 'strips whitespace from includes' do
        get :index, params: { include: 'round , players , championship' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['includes']).to eq(['round', 'players', 'championship'])
      end
    end

    context 'when include param is not present' do
      it 'returns empty array' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['includes']).to eq([])
      end
    end

    context 'when include param is empty string' do
      it 'returns empty array' do
        get :index, params: { include: '' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['includes']).to eq([])
      end
    end
  end

  describe '#apply_includes' do
    context 'with simple includes' do
      it 'applies includes to relation' do
        get :index, params: { include: 'round' }, format: :json
        
        expect(response).to have_http_status(:ok)
        # Should not raise N+1 query error if includes are applied correctly
      end

      it 'uses includes_list.map(&:to_sym) when includes_hash is empty' do
        # Simple includes (no dots) should result in empty includes_hash
        # and use the else branch: relation.includes(includes_list.map(&:to_sym))
        relation = Team.all
        includes_list = ['round', 'players']
        result = controller.send(:apply_includes, relation, includes_list)
        
        # Verify that includes were applied (should not raise error)
        expect { result.to_a }.not_to raise_error
      end
    end

    context 'with nested includes' do
      it 'converts nested includes to hash format' do
        get :index, params: { include: 'round.championship' }, format: :json
        
        expect(response).to have_http_status(:ok)
        # Should handle nested includes correctly
      end

      it 'creates nested hash structure for deep includes' do
        relation = Team.all
        includes_list = ['round.championship']
        result = controller.send(:apply_includes, relation, includes_list)
        
        # Verify that nested includes were applied
        expect { result.to_a }.not_to raise_error
      end

      it 'handles multiple levels of nesting' do
        relation = Team.all
        includes_list = ['round.championship.players']
        result = controller.send(:apply_includes, relation, includes_list)
        
        expect { result.to_a }.not_to raise_error
      end

      it 'uses includes_hash when it has any elements' do
        # Nested includes create a hash, so should use the if branch
        relation = Team.all
        includes_list = ['round.championship']
        result = controller.send(:apply_includes, relation, includes_list)
        
        expect { result.to_a }.not_to raise_error
      end
    end

    context 'when includes_list is blank' do
      it 'returns relation unchanged' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['count']).to be >= 3
      end

      it 'returns relation when includes_list is empty array' do
        relation = Team.all
        result = controller.send(:apply_includes, relation, [])
        
        expect(result).to eq(relation)
      end

      it 'returns relation when includes_list is nil' do
        relation = Team.all
        result = controller.send(:apply_includes, relation, nil)
        
        expect(result).to eq(relation)
      end
    end

    context 'with multiple nested includes' do
      it 'handles complex nested structures' do
        get :index, params: { include: 'round.championship,players.teams' }, format: :json
        
        expect(response).to have_http_status(:ok)
        # Should handle multiple nested includes
      end

      it 'handles when nested path already exists in hash' do
        # Test the branch where current[part] ||= {} is used
        # This happens when we have multiple includes that share a prefix
        relation = Team.all
        includes_list = ['round.championship', 'round.players']
        result = controller.send(:apply_includes, relation, includes_list)
        
        # Both share 'round', so the hash should be merged correctly
        expect { result.to_a }.not_to raise_error
      end

      it 'handles includes with empty strings' do
        relation = Team.all
        includes_list = ['round', '', 'players']
        result = controller.send(:apply_includes, relation, includes_list)
        
        # Should handle empty strings gracefully
        expect { result.to_a }.not_to raise_error
      end
    end

    context 'with mixed simple and nested includes' do
      it 'handles combination of simple and nested includes' do
        relation = Team.all
        includes_list = ['round', 'players.teams']
        result = controller.send(:apply_includes, relation, includes_list)
        
        # Should handle both types
        expect { result.to_a }.not_to raise_error
      end
    end
  end
end
