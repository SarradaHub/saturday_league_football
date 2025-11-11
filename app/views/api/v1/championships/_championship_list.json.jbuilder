# frozen_string_literal: true

championship_presenter = ChampionshipPresenter.new(championship)

json.extract! championship_presenter, :id, :name, :description, :created_at, :updated_at
json.round_total championship_presenter.round_total
