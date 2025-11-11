# frozen_string_literal: true

player_presenter = PlayerPresenter.new(player)

json.merge! player_presenter.as_json
