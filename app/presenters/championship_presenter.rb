# frozen_string_literal: true

class ChampionshipPresenter < ApplicationPresenter
  delegate :id, :name, :description, :created_at, :updated_at, to: :resource

  def as_json(*)
    {
      id: id,
      name: name,
      description: description,
      total_players: total_players,
      round_total: round_total,
      created_at: created_at,
      updated_at: updated_at,
      rounds: serialized_rounds,
      players: serialized_players
    }
  end

  def round_total
    resource.rounds.size
  end

  def total_players
    @total_players ||= resource.players.distinct.count
  end

  def rounds
    resource.rounds.order(round_date: :asc)
  end

  def players
    resource.players.distinct
  end

  private

  def serialized_rounds
    rounds.map { |round| RoundSerializer.new(round).as_json }
  end

  def serialized_players
    players.map { |player| PlayerPresenter.new(player).as_json }
  end
end
