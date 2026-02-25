 # frozen_string_literal: true

 module LeagueEngine
  module Rules
    # Regra de domínio responsável por garantir que um jogador não possa
    # ser goleiro e jogador de linha na mesma partida.
    #
    # É pensada para ser reutilizada tanto em validações em lote
    # (`PlayerStats::BulkUpsert`) quanto em operações pontuais.
    class GoalkeeperRule
      def self.valid_configuration?(rows)
        new(rows).valid_configuration?
      end

      def initialize(rows)
        @rows = Array(rows).map { |row| normalize(row) }
      end

      def valid_configuration?
        grouped_rows.none? do |_player_id, player_rows|
          goalkeeper_for?(player_rows) && line_player_for?(player_rows)
        end
      end

      private

      attr_reader :rows

      def grouped_rows
        rows.group_by { |row| row[:player_id] }
      end

      def goalkeeper_for?(player_rows)
        player_rows.any? { |row| truthy?(row[:was_goalkeeper]) }
      end

      def line_player_for?(player_rows)
        player_rows.any? do |row|
          next false unless row.key?(:was_goalkeeper)

          value = row[:was_goalkeeper]
          value == false || value.to_s == 'false'
        end
      end

      def normalize(row)
        hash = row.is_a?(Hash) ? row : row.to_h
        hash.symbolize_keys
      end

      def truthy?(value)
        value == true || value.to_s == 'true'
      end
    end
  end
 end

