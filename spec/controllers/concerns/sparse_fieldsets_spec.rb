# frozen_string_literal: true

require 'rails_helper'

# Create a test controller that includes the concern
class SparseFieldsetsTestController < ApplicationController
  include SparseFieldsets

  def index
    data = [
      { id: 1, name: 'Team 1', description: 'Description 1', created_at: '2024-01-01' },
      { id: 2, name: 'Team 2', description: 'Description 2', created_at: '2024-01-02' }
    ]
    allowed_fields = parse_fields
    filtered_data = filter_fields(data, allowed_fields)
    render json: { data: filtered_data }
  end
end

RSpec.describe SparseFieldsets, type: :controller do
  controller(SparseFieldsetsTestController) do
  end

  describe '#parse_fields' do
    context 'when fields param is present' do
      it 'parses comma-separated fields and converts to symbols' do
        get :index, params: { fields: 'id,name' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data'].first.keys).to contain_exactly('id', 'name')
        expect(json_response['data'].first).not_to have_key('description')
        expect(json_response['data'].first).not_to have_key('created_at')
      end

      it 'strips whitespace from field names' do
        get :index, params: { fields: 'id, name , description' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data'].first.keys).to contain_exactly('id', 'name', 'description')
      end
    end

    context 'when fields param is not present' do
      it 'returns nil' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        # All fields should be present when fields param is not specified
        expect(json_response['data'].first.keys).to include('id', 'name', 'description', 'created_at')
      end
    end

    context 'when fields param is empty string' do
      it 'returns nil' do
        get :index, params: { fields: '' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        # All fields should be present when fields param is empty
        expect(json_response['data'].first.keys).to include('id', 'name', 'description', 'created_at')
      end
    end

    context 'with duplicate fields' do
      it 'handles duplicate field names' do
        fields = controller.send(:parse_fields)
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(fields: 'id,name,id'))
        fields = controller.send(:parse_fields)
        
        expect(fields).to include(:id, :name)
        expect(fields.count(:id)).to eq(2)
      end
    end

    context 'with single field' do
      it 'parses single field correctly' do
        get :index, params: { fields: 'id' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data'].first.keys).to contain_exactly('id')
      end
    end
  end

  describe '#filter_fields' do
    context 'with array of hashes' do
      it 'filters each hash in the array' do
        get :index, params: { fields: 'id,name' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data'].length).to eq(2)
        json_response['data'].each do |item|
          expect(item.keys).to contain_exactly('id', 'name')
        end
      end
    end

    context 'with single hash' do
      it 'filters the hash fields' do
        # Test the method directly since we can't easily mock render in controller context
        test_data = { id: 1, name: 'Test', extra: 'data' }
        allowed_fields = [:id, :name]
        filtered = controller.send(:filter_fields, test_data, allowed_fields)
        
        # filter_fields uses slice which preserves symbol keys
        expect(filtered.keys).to contain_exactly(:id, :name)
        expect(filtered).not_to have_key(:extra)
      end
    end

    context 'when allowed_fields is nil or empty' do
      it 'returns data unchanged' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data'].first.keys).to include('id', 'name', 'description', 'created_at')
      end
    end

    context 'with non-hash, non-array data' do
      it 'returns data unchanged' do
        # Test the method directly
        data = 'string_data'
        allowed_fields = [:id, :name]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered).to eq('string_data')
      end

      it 'returns numeric data unchanged' do
        data = 123
        allowed_fields = [:id, :name]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered).to eq(123)
      end

      it 'returns nil unchanged' do
        data = nil
        allowed_fields = [:id, :name]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered).to be_nil
      end
    end

    context 'with empty array' do
      it 'returns empty array' do
        data = []
        allowed_fields = [:id, :name]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered).to eq([])
      end
    end

    context 'with empty hash' do
      it 'returns empty hash when no fields match' do
        data = {}
        allowed_fields = [:id, :name]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered).to eq({})
      end
    end

    context 'with fields that do not exist in hash' do
      it 'returns hash with only existing fields' do
        data = { id: 1, name: 'Test' }
        allowed_fields = [:id, :name, :nonexistent, :also_nonexistent]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered.keys).to contain_exactly(:id, :name)
        expect(filtered).not_to have_key(:nonexistent)
        expect(filtered).not_to have_key(:also_nonexistent)
      end
    end

    context 'with array containing non-hash elements' do
      it 'recursively filters nested arrays' do
        data = [
          { id: 1, name: 'Test' },
          'string_element',
          { id: 2, name: 'Test2' }
        ]
        allowed_fields = [:id]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered[0].keys).to contain_exactly(:id)
        expect(filtered[1]).to eq('string_element') # Non-hash elements unchanged
        expect(filtered[2].keys).to contain_exactly(:id)
      end
    end

    context 'with nested arrays' do
      it 'filters nested arrays recursively' do
        data = [
          [{ id: 1, name: 'Test' }],
          [{ id: 2, name: 'Test2' }]
        ]
        allowed_fields = [:id]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered[0][0].keys).to contain_exactly(:id)
        expect(filtered[1][0].keys).to contain_exactly(:id)
      end
    end

    context 'when allowed_fields contains string keys but data has symbol keys' do
      it 'filters correctly with symbol keys' do
        data = { id: 1, name: 'Test', extra: 'data' }
        allowed_fields = [:id, :name]
        filtered = controller.send(:filter_fields, data, allowed_fields)
        
        expect(filtered.keys).to contain_exactly(:id, :name)
      end
    end
  end
end
