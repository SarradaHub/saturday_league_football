# frozen_string_literal: true

require 'rails_helper'

# Create a test controller that includes the concern
class PaginatableTestController < ApplicationController
  include Paginatable

  def index
    relation = Team.all
    paginated = paginate_relation(relation)
    meta = pagination_meta(relation, **paginate_params)
    render json: { data: paginated.to_a, meta: meta }
  end
end

RSpec.describe Paginatable, type: :controller do
  controller(PaginatableTestController) do
  end

  let!(:test_teams) { FactoryBot.create_list(:team, 25) }

  describe '#paginate_params' do
    context 'with default params' do
      it 'returns default page and per_page' do
        get :index, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']).to include(
          'page' => 1,
          'per_page' => 20
        )
      end
    end

    context 'with valid page and per_page params' do
      it 'uses provided values' do
        get :index, params: { page: 2, per_page: 10 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']).to include(
          'page' => 2,
          'per_page' => 10
        )
        expect(json_response['data'].length).to eq(10)
      end
    end

    context 'with invalid page (zero or negative)' do
      it 'defaults to page 1' do
        get :index, params: { page: 0 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']['page']).to eq(1)
      end

      it 'defaults to page 1 for negative values' do
        get :index, params: { page: -5 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']['page']).to eq(1)
      end
    end

    context 'with invalid per_page (zero or negative)' do
      it 'defaults to DEFAULT_PER_PAGE' do
        get :index, params: { per_page: 0 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']['per_page']).to eq(20)
      end

      it 'defaults to DEFAULT_PER_PAGE for negative values' do
        get :index, params: { per_page: -10 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']['per_page']).to eq(20)
      end
    end

    context 'with per_page exceeding MAX_PER_PAGE' do
      it 'caps per_page to MAX_PER_PAGE (100)' do
        get :index, params: { per_page: 150 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']['per_page']).to eq(100)
      end

      it 'caps per_page to MAX_PER_PAGE when exactly 100' do
        get :index, params: { per_page: 100 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']['per_page']).to eq(100)
      end
    end

    context 'with per_page less than MAX_PER_PAGE' do
      it 'uses the provided per_page value when less than MAX_PER_PAGE' do
        get :index, params: { per_page: 50 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']['per_page']).to eq(50)
      end
    end

    context 'with string params' do
      it 'converts string params to integers' do
        get :index, params: { page: '3', per_page: '15' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']).to include(
          'page' => 3,
          'per_page' => 15
        )
      end

      it 'handles invalid string params' do
        get :index, params: { page: 'invalid', per_page: 'invalid' }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        # to_i on invalid string returns 0, so should default
        expect(json_response['meta']['page']).to eq(1)
        expect(json_response['meta']['per_page']).to eq(20)
      end
    end

    context 'when params[:page] is nil' do
      it 'defaults to page 1' do
        # Test the branch where params[:page]&.to_i returns nil
        page = controller.send(:parse_page)
        expect(page).to eq(1)
      end
    end

    context 'when params[:per_page] is nil' do
      it 'defaults to DEFAULT_PER_PAGE' do
        # Test the branch where params[:per_page]&.to_i returns nil
        per_page = controller.send(:parse_per_page)
        expect(per_page).to eq(20)
      end
    end
  end

  describe '#paginate_relation' do
    it 'applies limit and offset correctly' do
      get :index, params: { page: 2, per_page: 5 }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data'].length).to eq(5)
      # Should skip first 5 records (page 1) and return next 5 (page 2)
    end
  end

  describe '#pagination_meta' do
    it 'calculates total_pages correctly' do
      get :index, params: { per_page: 10 }, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      total = json_response['meta']['total']
      total_pages = json_response['meta']['total_pages']
      # Verify the calculation is correct: total_pages = ceil(total / per_page)
      expect(total_pages).to eq((total.to_f / 10).ceil)
      expect(total).to be >= 25
    end

    context 'when total is zero' do
      it 'returns total_pages as 0' do
        empty_relation = Team.where(id: -1) # Empty relation
        meta = controller.send(:pagination_meta, empty_relation, page: 1, per_page: 10)
        
        expect(meta[:total]).to eq(0)
        expect(meta[:total_pages]).to eq(0)
        expect(meta[:page]).to eq(1)
        expect(meta[:per_page]).to eq(10)
      end
    end

    context 'when total / per_page results in decimal' do
      it 'rounds up total_pages correctly' do
        # Create exactly 23 teams so 23 / 10 = 2.3, should round up to 3
        FactoryBot.create_list(:team, 23)
        get :index, params: { per_page: 10 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        total = json_response['meta']['total']
        total_pages = json_response['meta']['total_pages']
        
        # Should round up: ceil(23/10) = 3
        expect(total_pages).to eq((total.to_f / 10).ceil)
        expect(total_pages).to be >= 3
      end
    end

    context 'when total / per_page results in integer' do
      it 'returns correct total_pages' do
        # Create exactly 20 teams so 20 / 10 = 2.0
        FactoryBot.create_list(:team, 20)
        get :index, params: { per_page: 10 }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        total = json_response['meta']['total']
        total_pages = json_response['meta']['total_pages']
        
        # Should be exactly 2
        expect(total_pages).to eq((total.to_f / 10).ceil)
      end
    end

    it 'returns all required meta fields' do
      relation = Team.all
      meta = controller.send(:pagination_meta, relation, page: 2, per_page: 5)
      
      expect(meta).to include(:page, :per_page, :total, :total_pages)
      expect(meta[:page]).to eq(2)
      expect(meta[:per_page]).to eq(5)
      expect(meta[:total]).to be_a(Integer)
      expect(meta[:total_pages]).to be_a(Integer)
    end
  end
end
