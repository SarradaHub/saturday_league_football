# frozen_string_literal: true

json.array! @teans, partial: 'api/v1/teams/team_list', as: :team
