 # frozen_string_literal: true

 module LeagueEngine
  # Fachada principal da engine de regras de jogo.
  #
  # Esta classe consolida os principais fluxos de domínio relacionados a
  # sequência de partidas, substituições e regras de goleiro, delegando
  # a services existentes enquanto mantemos um ponto único de orquestração.
  class Engine
    class << self
      # Sugere o próximo confronto da rodada sem criar a partida.
      #
      # Retorna o mesmo payload atualmente exposto por
      # `Rounds::NextMatchGenerator.call(round:, create_match: false)`.
      def suggest_next_match(round:)
        MatchSequence.new(round: round).suggest
      end

      # Cria a próxima partida da rodada, opcionalmente recebendo o vencedor
      # escolhido em caso de empate na primeira partida.
      #
      # Retorna:
      # - um Hash com `:match` e `:queue`, ou
      # - um `Match` (quando o gerador não trabalha com fila),
      # exatamente como hoje em `Rounds::NextMatchGenerator`.
      def create_next_match(round:, winner_team_id: nil)
        MatchSequence.new(round: round, winner_team_id: winner_team_id).create_next_match
      end

      # Redistribui jogadores após a finalização de uma partida.
      #
      # Mantém a mesma semântica de `Rounds::NextMatchGenerator.redistribute_after_finalize`.
      def redistribute_after_finalize(match:)
        MatchSequence.redistribute_after_finalize(match)
      end

      # Finaliza uma partida (calcula placar, empate/vencedor) e dispara
      # redistribuição de jogadores.
      #
      # Mantém o contrato de `Matches::Finalize.call(match:)`.
      def finalize_match(match:)
        Matches::Finalize.call(match: match)
      end

      # Substituição dentro de uma partida específica.
      #
      # Mantém o contrato de `Matches::SubstitutePlayer.call`.
      def substitute_in_match(match:, player_id:, replacement_player_id:, team_id:)
        Matches::SubstitutePlayer.call(
          match: match,
          player_id: player_id,
          replacement_player_id: replacement_player_id,
          team_id: team_id
        )
      end

      # Substituição em nível de rodada (remove jogador da rodada e insere outro
      # disponível conforme fila/ordem de inscrição).
      #
      # Mantém o contrato de `Substitutions::ReplacePlayer.call`.
      def replace_in_round(round:, player_id:, match_id: nil)
        Substitutions::ReplacePlayer.call(round: round, player_id: player_id, match_id: match_id)
      end

      # Marca um jogador como goleiro em uma partida, garantindo que o vínculo
      # com o time existe (restaurando PlayerTeam soft-deleted quando preciso).
      #
      # Mantém o contrato de `PlayerStats::AddGoalkeeper.call`.
      def add_goalkeeper(match_id:, team_id:, player_id:)
        PlayerStats::AddGoalkeeper.call(
          match_id: match_id,
          team_id: team_id,
          player_id: player_id
        )
      end

      # Atualiza em massa as estatísticas de jogadores de uma partida,
      # aplicando regras de assistências e goleiro.
      #
      # Mantém o contrato de `PlayerStats::BulkUpsert.call`.
      def bulk_update_player_stats(match_id:, payload:)
        PlayerStats::BulkUpsert.call(match_id: match_id, payload: payload)
      end
    end
  end
 end

