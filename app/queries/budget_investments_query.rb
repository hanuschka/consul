class BudgetInvestmentsQuery < ApplicationQuery
  SEARCHABLE_FIELDS = %i[title].freeze
  SORTABLE_FIELDS = %i[total_votes flags_count].freeze
  FILTERABLE_FIELDS = %i[feasibility valuation_finished preselected selected winner].freeze
  MODERATION_STATUSES = %w[flagged ignored hidden].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |scope| apply_search(scope) }
      .then { |scope| apply_filters(scope) }
      .then { |scope| apply_moderation_filter(scope) }
      .then { |scope| apply_sorting(scope) }
  end

  private

    attr_reader :base_scope, :params

    def searchable_fields
      SEARCHABLE_FIELDS
    end

    def sortable_fields
      SORTABLE_FIELDS
    end

    def filterable_fields
      FILTERABLE_FIELDS
    end

    def apply_sorting(scope)
      field = params[:sort_by]&.to_sym
      return scope unless sortable_fields.include?(field)

      if scope.klass.respond_to?(:"sort_by_#{field}")
        scope.send(:"sort_by_#{field}")
      else
        direction = params[:sort_direction]&.downcase
        direction = %w[asc desc].include?(direction) ? direction : "asc"
        scope.order(field => direction)
      end
    end

    def apply_filters(scope)
      scope = super(scope)

      district_ids = Array(params[:district]).reject(&:blank?)
      if district_ids.present?
        scope = scope.joins(:map_location).where(map_locations: { registered_address_district_id: district_ids })
      end

      scope
    end

    def apply_moderation_filter(scope)
      statuses = Array(params[:moderation_status]).select { |s| MODERATION_STATUSES.include?(s) }
      return scope if statuses.blank?

      table = Budget::Investment.arel_table
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

    def apply_search(scope)
      search_term = searchable_params[:title]
      return scope if search_term.blank?

      scope.left_joins(:translations)
        .where("budget_investment_translations.locale = ?", I18n.locale)
        .where("budget_investment_translations.title ILIKE ?", "%#{escape_like(search_term)}%")
    end
end
