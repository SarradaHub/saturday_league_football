# frozen_string_literal: true

match_presenter = MatchPresenter.new(match)

json.merge! match_presenter.as_json
