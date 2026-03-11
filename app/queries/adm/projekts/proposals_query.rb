module Adm
  module Projekts
    class ProposalsQuery < ApplicationQuery
      MODERATION_STATUSES = %w[flagged ignored hidden].freeze

      def initialize(base_scope, params = {})
        @base_scope = base_scope
        @params = params
      end

      def call
        base_scope
          .then { |r| apply_moderation_filter(r) }
          .then { |r| apply_sorting(r) }
      end

      private

        attr_reader :base_scope, :params

        def apply_moderation_filter(scope)
          statuses = Array(params[:moderation_status]).select { |s| MODERATION_STATUSES.include?(s) }
          return scope if statuses.blank?

          conditions = statuses.map { |s| moderation_condition(s) }
          scope.where(conditions.reduce(:or))
        end

        def moderation_condition(status)
          table = Proposal.arel_table

          case status
          when "flagged"
            table[:flags_count].gt(0)
              .and(table[:ignored_flag_at].eq(nil))
              .and(table[:hidden_at].eq(nil))
          when "ignored"
            table[:flags_count].gt(0)
              .and(table[:ignored_flag_at].not_eq(nil))
              .and(table[:hidden_at].eq(nil))
          when "hidden"
            table[:hidden_at].not_eq(nil)
          end
        end

        def apply_sorting(scope)
          scope.order(id: :desc)
        end
    end
  end
end
