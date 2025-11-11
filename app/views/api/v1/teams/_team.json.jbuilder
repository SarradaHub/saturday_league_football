# frozen_string_literal: true

team_presenter = TeamPresenter.new(team)

json.merge! team_presenter.as_json
