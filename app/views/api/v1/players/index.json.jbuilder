# frozen_string_literal: true

json.array! @players, partial: 'api/v1/players/player_list', as: :player
