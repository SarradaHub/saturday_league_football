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
  let(:json_response) { JSON.parse(response.body) }

  def perform_index(params: {})
    get :index, params: params, format: :json
  end

  describe '#parse_fields' do
    context 'when fields param is present' do
      it 'parses comma-separated fields and converts to symbols' do
        perform_index(params: { fields: 'id,name' })
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].first.keys).to contain_exactly('id', 'name')
      end

      it 'omits unrequested fields' do
        perform_index(params: { fields: 'id,name' })
        expect(json_response['data'].first).not_to have_key('description')
        expect(json_response['data'].first).not_to have_key('created_at')
      end

      it 'strips whitespace from field names' do
        perform_index(params: { fields: 'id, name , description' })
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].first.keys).to contain_exactly('id', 'name', 'description')
      end
    end

    context 'when fields param is not present' do
      it 'returns nil' do
        perform_index
        expect(response).to have_http_status(:ok)
        # All fields should be present when fields param is not specified
        expect(json_response['data'].first.keys).to include('id', 'name', 'description', 'created_at')
      end
    end

    context 'when fields param is empty string' do
      it 'returns nil' do
        perform_index(params: { fields: '' })
        expect(response).to have_http_status(:ok)
        # All fields should be present when fields param is empty
        expect(json_response['data'].first.keys).to include('id', 'name', 'description', 'created_at')
      end
    end

    context 'with duplicate fields' do
      it 'handles duplicate field names' do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(fields: 'id,name,id'))
        fields = controller.send(:parse_fields)

        expect(fields).to include(:id, :name)
        expect(fields.count(:id)).to eq(2)
      end
    end

    context 'with single field' do
      it 'parses single field correctly' do
        perform_index(params: { fields: 'id' })
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].first.keys).to contain_exactly('id')
      end
    end
  end

  describe '#filter_fields' do
    context 'with array of hashes' do
      it 'filters each hash in the array' do
        perform_index(params: { fields: 'id,name' })
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(2)
      end

      it 'returns only requested keys' do
        perform_index(params: { fields: 'id,name' })
        keys = json_response['data'].map { |item| item.keys }
        expect(keys).to all(contain_exactly('id', 'name'))
      end
    end

    context 'with single hash' do
      let(:test_data) { { id: 1, name: 'Test', extra: 'data' } }
      let(:allowed_fields) { [:id, :name] }
      let(:filtered) { controller.send(:filter_fields, test_data, allowed_fields) }

      it 'filters the hash fields' do
        expect(filtered.keys).to contain_exactly(:id, :name)
      end

      it 'removes extra fields' do
        expect(filtered).not_to have_key(:extra)
      end
    end

    context 'when allowed_fields is nil or empty' do
      it 'returns data unchanged' do
        perform_index
        expect(response).to have_http_status(:ok)
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
      let(:data) { { id: 1, name: 'Test' } }
      let(:allowed_fields) { [:id, :name, :nonexistent, :also_nonexistent] }
      let(:filtered) { controller.send(:filter_fields, data, allowed_fields) }

      it 'returns hash with only existing fields' do
        expect(filtered.keys).to contain_exactly(:id, :name)
      end

      it 'removes missing fields' do
        expect(filtered).not_to have_key(:nonexistent)
        expect(filtered).not_to have_key(:also_nonexistent)
      end
    end

    context 'with array containing non-hash elements' do
      let(:data) do
        [
          { id: 1, name: 'Test' },
          'string_element',
          { id: 2, name: 'Test2' }
        ]
      end
      let(:allowed_fields) { [:id] }
      let(:filtered) { controller.send(:filter_fields, data, allowed_fields) }

      it 'filters hash elements' do
        expect(filtered[0].keys).to contain_exactly(:id)
      end

      it 'leaves non-hash elements unchanged' do
        expect(filtered[1]).to eq('string_element') # Non-hash elements unchanged
      end

      it 'filters remaining hash elements' do
        expect(filtered[2].keys).to contain_exactly(:id)
      end
    end

    context 'with nested arrays' do
      let(:data) do
        [
          [{ id: 1, name: 'Test' }],
          [{ id: 2, name: 'Test2' }]
        ]
      end
      let(:allowed_fields) { [:id] }
      let(:filtered) { controller.send(:filter_fields, data, allowed_fields) }

      it 'filters the first nested array' do
        expect(filtered[0][0].keys).to contain_exactly(:id)
      end

      it 'filters the second nested array' do
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
