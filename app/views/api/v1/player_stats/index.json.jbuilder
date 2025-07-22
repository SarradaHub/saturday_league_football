# frozen_string_literal: true

json.array! @player_stats, partial: 'api/v1/player_stats/stat', as: :stat
