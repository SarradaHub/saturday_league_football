# frozen_string_literal: true

championship_presenter = ChampionshipPresenter.new(championship)

json.merge! championship_presenter.as_json
