module Adm
  class DeficiencyReportsQuery < ApplicationQuery
    SEARCHABLE_FIELDS = %i[title].freeze
    SORTABLE_FIELDS = %i[id created_at status_changed_at].freeze
    FILTERABLE_FIELDS = %i[deficiency_report_category_id deficiency_report_status_id].freeze

    def initialize(base_scope, params = {})
      @base_scope = base_scope.joins(:translations)
      @params = params
    end

    def call
      base_scope
        .then { |r| apply_search(r) }
        .then { |r| apply_filters(r) }
        .then { |r| apply_sorting(r) }
        .distinct
    end

    private

      attr_reader :base_scope, :params

      def sortable_fields
        SORTABLE_FIELDS
      end

      def searchable_fields
        SEARCHABLE_FIELDS
      end

      def filterable_fields
        FILTERABLE_FIELDS
      end

      def apply_search(scope)
        search_value = params[:title__search]
        return scope if search_value.blank?

        scope.where("deficiency_report_translations.title ILIKE ?", "%#{escape_like(search_value)}%")
      end

      def apply_sorting(scope)
        field = params[:sort_by]&.to_sym
        return scope.order(id: :desc) unless sortable_fields.include?(field)

        direction = params[:sort_direction]&.downcase
        direction = %w[asc desc].include?(direction) ? direction : "asc"

        scope.order(field => direction)
      end
  end
end
