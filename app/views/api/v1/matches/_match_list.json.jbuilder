# frozen_string_literal: true

match_presenter = MatchPresenter.new(match)

json.extract! match_presenter, :id, :name, :draw, :created_at, :updated_at
json.team_1 match_presenter.team_1
json.team_2 match_presenter.team_2
json.team_1_goals match_presenter.team_1_goals
json.team_2_goals match_presenter.team_2_goals
json.winning_team match_presenter.winning_team
