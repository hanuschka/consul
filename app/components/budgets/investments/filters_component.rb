class Budgets::Investments::FiltersComponent < ApplicationComponent
  delegate :valid_filters, :current_filter, :link_list, :current_path_with_query_params, to: :helpers

  def render?
    valid_filters&.any?
  end

  private

  def selected_filter
    (current_filter.presence || "selected")
  end

    def filters
      valid_filters.map do |filter|
        [
          t("budgets.investments.index.filters.#{filter}"),
          current_path_with_query_params(filter: filter, page: 1),
          selected_filter == filter
        ]
      end
    end
end
