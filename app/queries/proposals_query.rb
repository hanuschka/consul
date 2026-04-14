class ProposalsQuery < ApplicationQuery
  SEARCHABLE_FIELDS = %i[title].freeze
  SORTABLE_FIELDS = %i[flags_count].freeze
  MODERATION_STATUSES = %w[flagged ignored hidden].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |r| apply_search(r) }
      .then { |r| apply_moderation_filter(r) }
      .then { |r| apply_sorting(r) }
  end

  private

    attr_reader :base_scope, :params

    def sortable_fields
      SORTABLE_FIELDS
    end

    def searchable_fields
      SEARCHABLE_FIELDS
    end

    def apply_search(scope)
      search_value = params[:title__search]
      return scope if search_value.blank?

      scope.joins(:translations)
        .where("proposal_translations.title ILIKE ?", "%#{escape_like(search_value)}%")
        .distinct
    end

    def apply_moderation_filter(scope)
      statuses = Array(params[:moderation_status]).select { |s| MODERATION_STATUSES.include?(s) }
      return scope if statuses.blank?

      table = Proposal.arel_table
      conditions = statuses.map { |s| moderation_condition(table, s) }
      scope.where(conditions.reduce(:or))
    end

    def moderation_condition(table, status)
      case status
      when "flagged"
        table[:flags_count].gt(0)
          .and(table[:ignored_flag_at].eq(nil))
          .and(table[:hidden_at].eq(nil))
      when "ignored"
        table[:ignored_flag_at].not_eq(nil)
          .and(table[:hidden_at].eq(nil))
      when "hidden"
        table[:hidden_at].not_eq(nil)
      end
    end

    def apply_sorting(scope)
      field = params[:sort_by]&.to_sym
      return scope.order(id: :desc) unless sortable_fields.include?(field)

      direction = params[:sort_direction]&.downcase
      direction = %w[asc desc].include?(direction) ? direction : "asc"

      scope.order(field => direction)
    end
end
