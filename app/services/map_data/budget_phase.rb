class MapData::BudgetPhase < ApplicationService
  def initialize(projekt_phase:, filter: nil, search: nil,
                 projekt_label_ids: nil, sentiment_id: nil)
    @projekt_phase = projekt_phase
    @filter = filter
    @search = search
    @projekt_label_ids = projekt_label_ids
    @sentiment_id = sentiment_id
  end

  def call
    budget = @projekt_phase&.budget

    return empty_collection if budget.blank?

    investment_ids = filtered_investments(budget).ids
    features = MapLocation.with_investment_associations
                          .where(mappable_id: investment_ids)
                          .map(&:features_json_data)
    features += MasterportalPin.standalone_features_for_phase(@projekt_phase)

    MapLocation.flatten_feature_collections(features)
  end

  private

    def filtered_investments(budget)
      resources = budget.investments

      if @search.present?
        resources = resources.search(@search)
      else
        resources = apply_label_filter(resources)
        resources = apply_sentiment_filter(resources)
      end

      resources.send(resolved_filter(budget))
    end

    def apply_label_filter(resources)
      return resources if @projekt_label_ids.blank?

      resources
        .joins(:projekt_labels)
        .where(projekt_labels: { id: @projekt_label_ids })
    end

    def apply_sentiment_filter(resources)
      return resources if @sentiment_id.blank?

      resources.where(sentiment_id: @sentiment_id)
    end

    def resolved_filter(budget)
      valid_filters = budget.investments_filters
      default = filter_default_for(budget.current_phase.kind)
      requested = @filter.presence || default

      valid_filters.include?(requested) ? requested : "all"
    end

    def filter_default_for(phase_kind)
      case phase_kind
      when "selecting" then "feasible"
      when "valuating" then "preselected"
      when "publishing_prices", "balloting", "reviewing_ballots" then "selected"
      when "finished" then "winners"
      end
    end

    def empty_collection
      { type: "FeatureCollection", features: [] }
    end
end
