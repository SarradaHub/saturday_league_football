 # frozen_string_literal: true

 module LeagueEngine
  # Adaptador entre a camada de domínio da engine e o service
  # `Rounds::NextMatchGenerator`, preservando contratos existentes enquanto
  # fornecemos uma API de domínio mais explícita.
  class MatchSequence
    class << self
      # Mantém o ponto de entrada usado após finalização de partidas.
      def redistribute_after_finalize(match)
        Rounds::NextMatchGenerator.redistribute_after_finalize(match)
      end
    end

    def initialize(round:, winner_team_id: nil)
      @round = round
      @winner_team_id = winner_team_id
    end

    # Sugere o próximo confronto sem criar a partida.
    def suggest
      call_next_match(create_match: false)
    end

    # Cria a próxima partida da rodada, respeitando o fluxo atual do
    # `NextMatchGenerator` (incluindo seleção de vencedor em empate inicial).
    def create_next_match
      call_next_match(create_match: true)
    end

    private

    attr_reader :round, :winner_team_id

    def call_next_match(create_match:)
      Rounds::NextMatchGenerator.call(
        round: round,
        winner_team_id: winner_team_id,
        create_match: create_match
      )
    end
  end
 end

