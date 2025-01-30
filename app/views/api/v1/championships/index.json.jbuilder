# frozen_string_literal: true

json.array! @championships, partial: 'championships/championship_list', as: :championship
