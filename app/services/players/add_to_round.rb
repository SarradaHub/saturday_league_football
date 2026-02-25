# frozen_string_literal: true

module Players
  class AddToRound < ApplicationService
    def initialize(player:, round_id:, goalkeeper_only: false)
      @player = player
      @round_id = round_id
      @goalkeeper_only = goalkeeper_only
    end

    def call
      round = Round.find(round_id)

      ActiveRecord::Base.transaction do
        pr = player.player_rounds.with_deleted.find_or_initialize_by(round: round)

        was_deleted = pr.respond_to?(:is_deleted?) && pr.is_deleted?

        pr.goalkeeper_only = goalkeeper_only || false
        pr.is_deleted = false if was_deleted && pr.respond_to?(:is_deleted?)

        pr.save!

        if was_deleted
          # Restaurar um vínculo soft-deletado não dispara callbacks de criação,
          # então chamamos manualmente a lógica de balanceamento/contagem.
          pr.send(:auto_balance_round_teams_on_create)
          pr.send(:update_championship_players_count)
        end

        player.reload
      end

      player
    rescue ActiveRecord::RecordNotUnique
      # Em caso de condição de corrida, garantimos que o vínculo existente seja reaproveitado.
      round = Round.find(round_id)
      pr = player.player_rounds.with_deleted.find_by(round: round)
      if pr
        pr.update!(
          goalkeeper_only: goalkeeper_only || false,
          is_deleted: false
        )
      end
      player.reload
      player
    end

    private

    attr_reader :player, :round_id, :goalkeeper_only
  end
end
