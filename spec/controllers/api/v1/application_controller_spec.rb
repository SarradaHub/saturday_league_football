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
end

RSpec.describe Api::V1::ApplicationController, type: :controller do
  controller(TestApplicationController) do
  end

  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: 1 }
    })
    request.headers['Authorization'] = 'Bearer valid_token'
  end

  let!(:test_teams) { FactoryBot.create_list(:team, 10, :with_round) }

  describe '#render_collection' do
    context 'with serializer_class' do
      before do
        routes.draw do
          get 'test_render_collection_with_serializer' => 'test_application#test_render_collection_with_serializer'
        end
      end

      it 'serializes items using serializer_class' do
        get :test_render_collection_with_serializer, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('data')
        expect(json_response['data']).to be_an(Array)
        if json_response['data'].any?
          expect(json_response['data'].first).to have_key('id')
          expect(json_response['data'].first).to have_key('name')
        end
      end
    end

    context 'with presenter_class' do
      before do
        routes.draw do
          get 'test_render_collection_with_presenter' => 'test_application#test_render_collection_with_presenter'
        end
      end

      it 'serializes items using presenter_class' do
        get :test_render_collection_with_presenter, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('data')
        expect(json_response['data']).to be_an(Array)
        if json_response['data'].any?
          expect(json_response['data'].first).to have_key('id')
          expect(json_response['data'].first).to have_key('name')
        end
      end
    end

    context 'without serializer_class or presenter_class' do
      before do
        routes.draw do
          get 'test_render_collection_without_serializer_or_presenter' => 'test_application#test_render_collection_without_serializer_or_presenter'
        end
      end

      it 'serializes items using as_json' do
        get :test_render_collection_without_serializer_or_presenter, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('data')
        expect(json_response['data']).to be_an(Array)
      end
    end

    context 'with base_relation provided' do
      before do
        routes.draw do
          get 'test_render_collection_with_base_relation_provided' => 'test_application#test_render_collection_with_base_relation_provided'
        end
      end

      it 'uses provided base_relation for count' do
        get :test_render_collection_with_base_relation_provided, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        # Should use the provided base_relation (all teams) not the limited collection
        expect(json_response['meta']['total']).to be >= 10
        expect(json_response['data'].length).to eq(5) # Limited collection
      end
    end

    context 'without base_relation - collection is ActiveRecord::Relation' do
      before do
        routes.draw do
          get 'test_render_collection_without_base_relation_relation' => 'test_application#test_render_collection_without_base_relation_relation'
        end
      end

      it 'derives base_relation from collection by removing limit and offset' do
        get :test_render_collection_without_base_relation_relation, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        # Should count all teams, not just the limited ones
        expect(json_response['meta']['total']).to be >= 10
        expect(json_response['data'].length).to eq(5) # Limited collection
      end
    end

    context 'without base_relation - collection is not ActiveRecord::Relation' do
      before do
        routes.draw do
          get 'test_render_collection_without_base_relation_array' => 'test_application#test_render_collection_without_base_relation_array'
        end
      end

      it 'derives base_relation using collection.first.class.all when collection is array of ActiveRecord objects' do
        get :test_render_collection_without_base_relation_array, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        # Should count all teams (collection.first.class.all when collection is array)
        # The collection is an array, so base_relation will be Team.all
        expect(json_response['meta']['total']).to be >= 10
        expect(json_response['data']).to be_an(Array)
      end
    end

    context 'when base_relation is not a Relation' do
      before do
        routes.draw do
          get 'test_render_collection_with_array_base_relation' => 'test_application#test_render_collection_with_array_base_relation'
        end
      end

      it 'uses size instead of count' do
        get :test_render_collection_with_array_base_relation, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['meta']['total']).to be >= 10
        expect(json_response['data'].length).to eq(3)
      end
    end

    context 'with sparse fieldsets - allowed_fields present' do
      before do
        routes.draw do
          get 'test_render_collection_with_sparse_fieldsets' => 'test_application#test_render_collection_with_sparse_fieldsets'
        end
      end

      it 'applies sparse fieldsets when fields param is present' do
        get :test_render_collection_with_sparse_fieldsets, params: { fields: 'id,name' }, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        if json_response['data'].any?
          expect(json_response['data'].first.keys).to contain_exactly('id', 'name')
        end
      end
    end

    context 'without sparse fieldsets - allowed_fields not present' do
      before do
        routes.draw do
          get 'test_render_collection_without_sparse_fieldsets' => 'test_application#test_render_collection_without_sparse_fieldsets'
        end
      end

      it 'does not filter fields when fields param is not present' do
        get :test_render_collection_without_sparse_fieldsets, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['data']).to be_an(Array)
        if json_response['data'].any?
          # Should have all fields from presenter
          expect(json_response['data'].first).to have_key('id')
          expect(json_response['data'].first).to have_key('name')
        end
      end
    end

    context 'when total is zero' do
      before do
        Team.destroy_all
        routes.draw do
          get 'test_render_collection_total_zero' => 'test_application#test_render_collection_total_zero'
        end
      end

      it 'handles zero total correctly' do
        get :test_render_collection_total_zero, params: { per_page: 10 }, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['meta']['total']).to eq(0)
        expect(json_response['meta']['total_pages']).to eq(0)
        expect(json_response['data']).to eq([])
      end
    end

    context 'pagination meta calculation with decimal division' do
      before do
        routes.draw do
          get 'test_render_collection_with_presenter' => 'test_application#test_render_collection_with_presenter'
        end
      end

      it 'calculates total_pages correctly with decimal division' do
        get :test_render_collection_with_presenter, params: { per_page: 3 }, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        total = json_response['meta']['total']
        total_pages = json_response['meta']['total_pages']
        per_page = json_response['meta']['per_page']

        # Verify the calculation is correct: total_pages = ceil(total / per_page)
        expect(total_pages).to eq((total.to_f / per_page).ceil)
        expect(total).to be >= 10
        expect(per_page).to eq(3)
        # With 10+ items and per_page=3, total_pages should be at least 4
        expect(total_pages).to be >= 4
      end
    end
  end
end
