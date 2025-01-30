# frozen_string_literal: true

json.array! @rounds, partial: 'api/v1/rounds/round_list', as: :round
