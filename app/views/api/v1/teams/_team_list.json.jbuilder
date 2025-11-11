# frozen_string_literal: true

team_presenter = TeamPresenter.new(team)

json.extract! team_presenter, :id, :name, :round_id, :created_at, :updated_at
