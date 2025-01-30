# frozen_string_literal: true

json.array! @championships, partial: 'api/v1/championships/championship_list', as: :championship
