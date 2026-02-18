class BudgetInvestmentsQuery < ApplicationQuery
  SEARCHABLE_FIELDS = %i[title].freeze
  SORTABLE_FIELDS = %i[total_votes].freeze
  FILTERABLE_FIELDS = %i[feasibility valuation_finished preselected selected winner].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |scope| apply_search(scope) }
      .then { |scope| apply_filters(scope) }
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
      return scope unless params[:sort_by]&.to_sym == :total_votes

      direction = params[:sort_direction]&.downcase
      direction = %w[asc desc].include?(direction) ? direction : "asc"

      scope.reorder(nil)
        .left_joins(:votes_for)
        .group("budget_investments.id")
        .order(Arel.sql("COALESCE(SUM(votes.vote_weight), 0) + budget_investments.physical_votes #{direction}"))
    end

    def apply_search(scope)
      search_term = searchable_params[:title]
      return scope if search_term.blank?

      scope.left_joins(:translations)
        .where("budget_investment_translations.locale = ?", I18n.locale)
        .where("budget_investment_translations.title ILIKE ?", "%#{escape_like(search_term)}%")
    end
end
