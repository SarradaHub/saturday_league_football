# frozen_string_literal: true

round_presenter = RoundPresenter.new(round)

json.extract! round_presenter, :id, :name, :round_date, :championship_id, :created_at, :updated_at
