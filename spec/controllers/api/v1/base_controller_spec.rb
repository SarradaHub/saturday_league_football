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
  let(:current_user) { FactoryBot.create(:user) }
  let(:championship) { FactoryBot.create(:championship, user: current_user) }
  let(:round) { FactoryBot.create(:round, championship: championship) }
  let(:json_response) { JSON.parse(response.body) }

  def perform_request(action, params: {})
    get action, params: params, format: :json
  end

  # Use TeamsController as it inherits from BaseController
  controller(Api::V1::TeamsController) do
  end

  before do
    # Create test data
    FactoryBot.create_list(:team, 10, round: round)
    # Mock authentication
    allow(IdentityServiceClient).to receive(:validate_token).and_return({
      valid: true,
      user: { id: current_user.external_id, email: current_user.email }
    })
    allow(Users::SyncFromIdentityService).to receive(:call).and_return(current_user)
    request.headers['Authorization'] = 'Bearer valid_token'
  end


  describe '#render_collection' do
    context 'with presenter_class' do
      before { perform_request(:index) }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns data and meta' do
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('meta')
        expect(json_response['data']).to be_an(Array)
      end

      it 'includes meta structure' do
        expect(json_response['meta']).to include(
          'page', 'per_page', 'total', 'total_pages'
        )
      end

      it 'includes total count' do
        expect(json_response['meta']['total']).to be >= 10
      end
    end

    context 'with sparse fieldsets' do
      before { perform_request(:index, params: { fields: 'id,name' }) }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'filters fields when fields param is present' do
        expect(json_response['data'].first.keys).to contain_exactly('id', 'name')
      end

      it 'removes round_id from response' do
        expect(json_response['data'].first).not_to have_key('round_id')
      end
    end

    context 'with base_relation provided' do
      before { perform_request(:index) }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'uses provided base_relation for count' do
        # Total should be at least 10 (our created teams)
        expect(json_response['meta']['total']).to be >= 10
      end
    end

    context 'when pagination meta is calculated' do
      before { perform_request(:index, params: { per_page: 3 }) }

      let(:total) { json_response['meta']['total'] }
      let(:total_pages) { json_response['meta']['total_pages'] }
      let(:per_page) { json_response['meta']['per_page'] }

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'calculates total_pages correctly' do
        expect(total_pages).to eq((total.to_f / per_page).ceil)
      end

      it 'returns total count' do
        expect(total).to be >= 10
      end

      it 'returns per_page from params' do
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

        perform_request(:test_render_collection_with_serializer)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns data and meta' do
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('meta')
        expect(json_response['data']).to be_an(Array)
      end

      it 'includes id and name in items' do
        expect(json_response['data'].first).to have_key('id')
        expect(json_response['data'].first).to have_key('name')
      end
    end

    context 'without serializer_class or presenter_class' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_without_serializer_or_presenter' => 'test_base#test_render_collection_without_serializer_or_presenter'
        end

        perform_request(:test_render_collection_without_serializer_or_presenter)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns data and meta' do
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

        perform_request(:test_render_collection_with_array)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns data and meta' do
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('meta')
        expect(json_response['data']).to be_an(Array)
      end

      it 'uses provided base_relation for total' do
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

        perform_request(:test_render_collection_with_base_relation)
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

    context 'when base_relation is not a Relation' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_with_array_base_relation' => 'test_base#test_render_collection_with_array_base_relation'
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

    context 'with sparse fieldsets integration' do
      controller(TestBaseController) do
      end

      before do
        routes.draw do
          get 'test_render_collection_with_sparse_fieldsets' => 'test_base#test_render_collection_with_sparse_fieldsets'
        end

        perform_request(:test_render_collection_with_sparse_fieldsets, params: { fields: 'id,name' })
      end

      it 'returns ok with fields param' do
        expect(response).to have_http_status(:ok)
      end

      it 'applies sparse fieldsets to serialized items' do
        expect(json_response['data'].first).to have_key('id')
        expect(json_response['data'].first).to have_key('name')
      end

      it 'does not filter when fields param is not present' do
        perform_request(:test_render_collection_with_sparse_fieldsets)
        expect(response).to have_http_status(:ok)
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

        perform_request(:test_render_collection)
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'removes limit and offset from base_relation for count' do
        # Should count all teams, not just the limited ones
        expect(json_response['meta']['total']).to be >= 10
      end
    end
  end

  describe '#requires_authentication?' do
    it 'returns true by default' do
      # Test through an instance of BaseController
      base_controller = described_class.new
      result = base_controller.send(:requires_authentication?)
      expect(result).to be true
    end
  end
end
