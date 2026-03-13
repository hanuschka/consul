class Kern::Table::HeaderComponent < ApplicationComponent
  delegate :current_path_with_query_params, to: :helpers

  def initialize(column, label, **options)
    @column = column.to_s
    @label = label.to_s
    @sort = options.delete(:sort)
    @search = options.delete(:search)
    @filter_options = options.delete(:filter_options)&.reject { |k, _v| k.nil? } || {}
  end

  private

    def show_sort?
      @sort.present?
    end

    def show_filter?
      @search.present? || @filter_options.present?
    end

    def sorted?
      return false unless @sort

      params[:sort_by].presence == @column
    end

    def filtered?
      params["#{@column}__search"].present? ||
        params[@column].present?
    end

    def filter_param_values
      Array(params[@column]).map(&:to_s)
    end

    def target_url
      params = {}
      params.merge!(sort_params)

      current_path_with_query_params(params)
    end

    def aria_sort
      return unless @sort
      return "none" unless sorted?

      current_direction == "desc" ? "descending" : "ascending"
    end

    def icon
      return "unfold_more" unless sorted?

      current_direction == "desc" ? "arrow_upward" : "arrow_downward"
    end

    def current_direction
      params[:sort_direction] == "desc" ? "desc" : "asc"
    end

    def target_direction
      current_direction == "desc" ? "asc" : "desc"
    end

    def sort_params
      { sort_by: @column, sort_direction: target_direction }
    end

    def action_label
      t("shared.table.sort.action_label",
        column_label: @label,
        direction: readable_direction(target_direction)
       )
    end

    def status_text
      if sorted?
        t("shared.table.sort.status_text_sorted",
          column_label: @label,
          direction: readable_direction(current_direction))
      else
        t("shared.table.sort.status_text_unsorted")
      end
    end

    def status_id
      "sort-status-#{@column.parameterize}"
    end

    def readable_direction(direction)
      t("shared.table.sort.directions.#{direction}")
    end
end
