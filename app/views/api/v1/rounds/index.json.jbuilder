# frozen_string_literal: true

json.array! @rounds, partial: 'rounds/round_list', as: :round
