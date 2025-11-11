# frozen_string_literal: true

round_presenter = RoundPresenter.new(round)

json.merge! round_presenter.as_json
