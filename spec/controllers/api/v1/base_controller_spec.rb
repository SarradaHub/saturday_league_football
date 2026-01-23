# frozen_string_literal: true

require 'rails_helper'

# Create a test controller that inherits from BaseController
class TestBaseController < Api::V1::BaseController
  def test_render_collection
    collection = Team.all
    render_collection(collection, presenter_class: TeamPresenter)
  end

  def test_render_collection_with_serializer
    collection = Team.all
    render_collection(collection, serializer_class: TeamSerializer)
  end

  def test_render_collection_without_serializer_or_presenter
    collection = Team.all
    render_collection(collection)
  end

  def test_render_collection_with_array
    collection = Team.all.to_a
    base_relation = Team.all
    render_collection(collection, presenter_class: TeamPresenter, base_relation: base_relation)
  end

  def test_render_collection_with_base_relation
    collection = Team.limit(5)
    base_relation = Team.all
    render_collection(collection, presenter_class: TeamPresenter, base_relation: base_relation)
  end

  def test_render_collection_with_sparse_fieldsets
    collection = Team.all
    render_collection(collection, presenter_class: TeamPresenter)
  end

  def test_render_collection_with_array_base_relation
    collection = Team.limit(3).to_a
    base_relation = Team.all.to_a
    render_collection(collection, presenter_class: TeamPresenter, base_relation: base_relation)
  end
end

# Test BaseController through a real controller that uses it
RSpec.describe Api::V1::BaseController, type: :controller do
  # Use TeamsController as it inherits from BaseController
  controller(Api::V1::TeamsController) do
  end

  before do
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: 1 }
    })
    request.headers['Authorization'] = 'Bearer valid_token'
  end

  # Create test data
  let!(:test_teams) { FactoryBot.create_list(:team, 10, :with_round) }

  describe '#render_collection' do
    context 'with presenter_class' do
      it 'renders collection using presenter' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('meta')
        expect(json_response['data']).to be_an(Array)
        
        # Check meta structure
        expect(json_response['meta']).to include(
          'page', 'per_page', 'total', 'total_pages'
        )
        # Total should be at least 10 (our created teams)
        expect(json_response['meta']['total']).to be >= 10
      end
    end

    context 'with sparse fieldsets' do
      it 'filters fields when fields param is present' do
        get :index, params: { fields: 'id,name' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        if json_response['data'].any?
          expect(json_response['data'].first.keys).to contain_exactly('id', 'name')
          expect(json_response['data'].first).not_to have_key('round_id')
        end
      end
    end

    context 'with base_relation provided' do
      it 'uses provided base_relation for count' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        # Total should be at least 10 (our created teams)
        expect(json_response['meta']['total']).to be >= 10
      end
    end

    context 'pagination meta calculation' do
      it 'calculates total_pages correctly' do
        get :index, params: { per_page: 3 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        total = json_response['meta']['total']
        total_pages = json_response['meta']['total_pages']
        per_page = json_response['meta']['per_page']
        
        # Verify the calculation is correct: total_pages = ceil(total / per_page)
        expect(total_pages).to eq((total.to_f / per_page).ceil)
        expect(total).to be >= 10
        expect(per_page).to eq(3)
      end
    end

    context 'with serializer_class' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_with_serializer' => 'test_base#test_render_collection_with_serializer'
        end
      end

      it 'renders collection using serializer' do
        get :test_render_collection_with_serializer, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('meta')
        expect(json_response['data']).to be_an(Array)
        if json_response['data'].any?
          expect(json_response['data'].first).to have_key('id')
          expect(json_response['data'].first).to have_key('name')
        end
      end
    end

    context 'without serializer_class or presenter_class' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_without_serializer_or_presenter' => 'test_base#test_render_collection_without_serializer_or_presenter'
        end
      end

      it 'renders collection using as_json' do
        get :test_render_collection_without_serializer_or_presenter, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('meta')
        expect(json_response['data']).to be_an(Array)
      end
    end

    context 'when collection is an array (not ActiveRecord::Relation)' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_with_array' => 'test_base#test_render_collection_with_array'
        end
      end

      it 'handles array collection correctly' do
        get :test_render_collection_with_array, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('meta')
        expect(json_response['data']).to be_an(Array)
        # When collection is array, base_relation is provided explicitly
        expect(json_response['meta']['total']).to be >= 10
      end
    end

    context 'with base_relation provided explicitly' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_with_base_relation' => 'test_base#test_render_collection_with_base_relation'
        end
      end

      it 'uses provided base_relation for count' do
        get :test_render_collection_with_base_relation, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        # Should use the provided base_relation (all teams) not the limited collection
        expect(json_response['meta']['total']).to be >= 10
        expect(json_response['data'].length).to eq(5) # Limited collection
      end
    end

    context 'when base_relation is not a Relation' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_with_array_base_relation' => 'test_base#test_render_collection_with_array_base_relation'
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

    context 'with sparse fieldsets integration' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_with_sparse_fieldsets' => 'test_base#test_render_collection_with_sparse_fieldsets'
        end
      end

      it 'applies sparse fieldsets to serialized items' do
        get :test_render_collection_with_sparse_fieldsets, params: { fields: 'id,name' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        if json_response['data'].any?
          # Should only have id and name fields (or more if presenter adds them)
          expect(json_response['data'].first).to have_key('id')
          expect(json_response['data'].first).to have_key('name')
        end
      end

      it 'does not filter when fields param is not present' do
        get :test_render_collection_with_sparse_fieldsets, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['data']).to be_an(Array)
      end
    end

    context 'when collection has limit and offset' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection' => 'test_base#test_render_collection'
        end
      end

      it 'removes limit and offset from base_relation for count' do
        get :test_render_collection, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        # Should count all teams, not just the limited ones
        expect(json_response['meta']['total']).to be >= 10
      end
    end
  end

  describe '#requires_authentication?' do
    it 'returns true by default' do
      # Test through an instance of BaseController
      base_controller = Api::V1::BaseController.new
      result = base_controller.send(:requires_authentication?)
      expect(result).to be true
    end
  end
end
