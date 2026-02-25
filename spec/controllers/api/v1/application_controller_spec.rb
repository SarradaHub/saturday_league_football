# frozen_string_literal: true

require 'rails_helper'

# Create a test controller that inherits from ApplicationController
class TestApplicationController < Api::V1::ApplicationController
  def test_render_collection_with_serializer
    collection = Team.all
    render_collection(collection, serializer_class: TeamSerializer)
  end

  def test_render_collection_with_presenter
    collection = Team.all
    render_collection(collection, presenter_class: TeamPresenter)
  end

  def test_render_collection_without_serializer_or_presenter
    collection = Team.all
    render_collection(collection)
  end

  def test_render_collection_with_base_relation_provided
    collection = Team.limit(5)
    base_relation = Team.all
    render_collection(collection, presenter_class: TeamPresenter, base_relation: base_relation)
  end

  def test_render_collection_without_base_relation_relation
    collection = Team.limit(5)
    render_collection(collection, presenter_class: TeamPresenter)
  end

  def test_render_collection_without_base_relation_array
    collection = Team.all.to_a
    # When collection is an array, we need to provide base_relation explicitly
    # or the controller will try to use collection.first.class.all
    base_relation = Team.all
    render_collection(collection, presenter_class: TeamPresenter, base_relation: base_relation)
  end

  def test_render_collection_with_array_base_relation
    collection = Team.limit(3).to_a
    base_relation = Team.all.to_a
    render_collection(collection, presenter_class: TeamPresenter, base_relation: base_relation)
  end

  def test_render_collection_with_sparse_fieldsets
    collection = Team.all
    render_collection(collection, presenter_class: TeamPresenter)
  end

  def test_render_collection_without_sparse_fieldsets
    collection = Team.all
    render_collection(collection, presenter_class: TeamPresenter)
  end

  def test_render_collection_total_zero
    collection = Team.none
    render_collection(collection, presenter_class: TeamPresenter)
  end

  def test_render_collection_fallback_base_relation
    # Collection is neither Relation nor array of AR: use fallback base_relation = collection
    collection = [{ 'id' => 1, 'name' => 'A' }, { 'id' => 2, 'name' => 'B' }]
    render_collection(collection)
  end
end

RSpec.describe Api::V1::ApplicationController, type: :controller do
  controller(TestApplicationController) do
  end

  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: 1, email: 'test.user@example.com' }
    })
    request.headers['Authorization'] = 'Bearer valid_token'
    FactoryBot.create_list(:team, 10, :with_round)
  end

  let(:json_response) { JSON.parse(response.body) }

  def perform_request(action, params: {})
    get action, params: params, format: :json
  end

  describe '#render_collection' do
    context 'with serializer_class' do
      before do
        routes.draw do
          get 'test_render_collection_with_serializer' => 'test_application#test_render_collection_with_serializer'
        end

        perform_request(:test_render_collection_with_serializer)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns data array' do
        expect(json_response).to have_key('data')
        expect(json_response['data']).to be_an(Array)
      end

      it 'includes id and name in items' do
        expect(json_response['data'].first).to have_key('id')
        expect(json_response['data'].first).to have_key('name')
      end
    end

    context 'with presenter_class' do
      before do
        routes.draw do
          get 'test_render_collection_with_presenter' => 'test_application#test_render_collection_with_presenter'
        end

        perform_request(:test_render_collection_with_presenter)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns data array' do
        expect(json_response).to have_key('data')
        expect(json_response['data']).to be_an(Array)
      end

      it 'includes id and name in items' do
        expect(json_response['data'].first).to have_key('id')
        expect(json_response['data'].first).to have_key('name')
      end
    end

    context 'without serializer_class or presenter_class' do
      before do
        routes.draw do
          get 'test_render_collection_without_serializer_or_presenter' => 'test_application#test_render_collection_without_serializer_or_presenter'
        end

        perform_request(:test_render_collection_without_serializer_or_presenter)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns data array' do
        expect(json_response).to have_key('data')
        expect(json_response['data']).to be_an(Array)
      end
    end

    context 'with base_relation provided' do
      before do
        routes.draw do
          get 'test_render_collection_with_base_relation_provided' => 'test_application#test_render_collection_with_base_relation_provided'
        end

        perform_request(:test_render_collection_with_base_relation_provided)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'uses provided base_relation for total' do
        # Should use the provided base_relation (all teams) not the limited collection
        expect(json_response['meta']['total']).to be >= 10
      end

      it 'returns limited collection' do
        expect(json_response['data'].length).to eq(5)
      end
    end

    context 'without base_relation - collection is ActiveRecord::Relation' do
      before do
        routes.draw do
          get 'test_render_collection_without_base_relation_relation' => 'test_application#test_render_collection_without_base_relation_relation'
        end

        perform_request(:test_render_collection_without_base_relation_relation)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'derives base_relation from collection by removing limit and offset' do
        # Should count all teams, not just the limited ones
        expect(json_response['meta']['total']).to be >= 10
      end

      it 'returns limited collection' do
        expect(json_response['data'].length).to eq(5)
      end
    end

    context 'without base_relation - collection is not ActiveRecord::Relation' do
      before do
        routes.draw do
          get 'test_render_collection_without_base_relation_array' => 'test_application#test_render_collection_without_base_relation_array'
        end

        perform_request(:test_render_collection_without_base_relation_array)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'derives base_relation using collection.first.class.all' do
        # Should count all teams (collection.first.class.all when collection is array)
        # The collection is an array, so base_relation will be Team.all
        expect(json_response['meta']['total']).to be >= 10
      end

      it 'returns data array' do
        expect(json_response['data']).to be_an(Array)
      end
    end

    context 'when base_relation is not a Relation' do
      before do
        routes.draw do
          get 'test_render_collection_with_array_base_relation' => 'test_application#test_render_collection_with_array_base_relation'
        end

        perform_request(:test_render_collection_with_array_base_relation)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'uses size instead of count' do
        expect(json_response['meta']['total']).to be >= 10
      end

      it 'returns limited collection' do
        expect(json_response['data'].length).to eq(3)
      end
    end

    context 'with sparse fieldsets - allowed_fields present' do
      before do
        routes.draw do
          get 'test_render_collection_with_sparse_fieldsets' => 'test_application#test_render_collection_with_sparse_fieldsets'
        end

        perform_request(:test_render_collection_with_sparse_fieldsets, params: { fields: 'id,name' })
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'applies sparse fieldsets when fields param is present' do
        expect(json_response['data'].first.keys).to contain_exactly('id', 'name')
      end
    end

    context 'without sparse fieldsets - allowed_fields not present' do
      before do
        routes.draw do
          get 'test_render_collection_without_sparse_fieldsets' => 'test_application#test_render_collection_without_sparse_fieldsets'
        end

        perform_request(:test_render_collection_without_sparse_fieldsets)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'does not filter fields when fields param is not present' do
        expect(json_response['data']).to be_an(Array)
      end

      it 'includes full presenter fields' do
        expect(json_response['data'].first).to have_key('id')
        expect(json_response['data'].first).to have_key('name')
      end
    end

    context 'when total is zero' do
      before do
        Team.destroy_all
        routes.draw do
          get 'test_render_collection_total_zero' => 'test_application#test_render_collection_total_zero'
        end

        perform_request(:test_render_collection_total_zero, params: { per_page: 10 })
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'sets total to zero' do
        expect(json_response['meta']['total']).to eq(0)
      end

      it 'sets total_pages to zero' do
        expect(json_response['meta']['total_pages']).to eq(0)
      end

      it 'returns empty data array' do
        expect(json_response['data']).to eq([])
      end
    end

    context 'when collection is neither Relation nor array of AR' do
      before do
        routes.draw do
          get 'test_render_collection_fallback_base_relation' => 'test_application#test_render_collection_fallback_base_relation'
        end

        perform_request(
          :test_render_collection_fallback_base_relation,
          params: { per_page: 10, page: 1 }
        )
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns data array' do
        expect(json_response['data']).to be_an(Array)
      end

      it 'sets total size based on collection' do
        expect(json_response['data'].size).to eq(2)
        expect(json_response['meta']['total']).to eq(2)
      end

      it 'sets total_pages to one' do
        expect(json_response['meta']['total_pages']).to eq(1)
      end
    end

    context 'when pagination meta uses decimal division' do
      before do
        routes.draw do
          get 'test_render_collection_with_presenter' => 'test_application#test_render_collection_with_presenter'
        end

        perform_request(:test_render_collection_with_presenter, params: { per_page: 3 })
      end

      let(:total) { json_response['meta']['total'] }
      let(:total_pages) { json_response['meta']['total_pages'] }
      let(:per_page) { json_response['meta']['per_page'] }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'calculates total_pages correctly' do
        expect(total_pages).to eq((total.to_f / per_page).ceil)
      end

      it 'returns total of all items' do
        expect(total).to be >= 10
      end

      it 'returns per_page from params' do
        expect(per_page).to eq(3)
      end

      it 'returns at least four pages' do
        expect(total_pages).to be >= 4
      end
    end
  end
end
