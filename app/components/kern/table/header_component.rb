class Kern::Table::HeaderComponent < ApplicationComponent
  delegate :current_path_with_query_params, to: :helpers

  def initialize(column, label, **options)
    @column = column.to_s
    @label = label.to_s
    @sort = options.delete(:sort)
    @search = options.delete(:search)
    @filter_options = options.delete(:filter_options)&.reject { |k, _v| k.nil? } || {}
    @default = options.delete(:default)
    @date_range = options.delete(:date_range)
    @data_field = options.delete(:data_field)
  end

  def filter_pills(current_params)
    pills = []

    if @search && (search_value = current_params["#{@column}__search"].to_s).present?
      pills << {
        label: "#{@label}: #{search_value}",
        remove_key: "#{@column}__search"
      }
    end

    if @filter_options.present?
      current = Array(current_params[@column]).map(&:to_s).compact_blank

      current.each do |value|
        option = @filter_options.find { |v, _| v.to_s == value }
        option_label = option ? option[1] : value
        pills << {
          label: "#{@label}: #{option_label}",
          remove_array_key: @column,
          remove_array_value: value,
          keep_empty_marker: @default.present?
        }
      end
    end

    if @date_range
      from = current_params["#{@column}__from"].presence
      to = current_params["#{@column}__to"].presence
      if from || to
        pills << {
          label: "#{@label}: #{date_range_label(from, to)}",
          remove_keys: ["#{@column}__from", "#{@column}__to"]
        }
      end
    end

    pills
  end

  private

    def show_sort?
      @sort.present?
    end

    def show_filter?
      @search.present? || @filter_options.present? || @date_range.present?
    end

    def sorted?
      return false unless @sort

      params[:sort_by].presence == @column
    end

    def filtered?
      params["#{@column}__search"].present? ||
        Array(params[@column]).map(&:to_s).compact_blank.present? ||
        params["#{@column}__from"].present? ||
        params["#{@column}__to"].present?
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

    def date_range_label(from, to)
      if from && to
        "#{format_date(from)} – #{format_date(to)}"
      elsif from
        I18n.t("shared.table.filter.date_range.from_only", date: format_date(from))
      elsif to
        I18n.t("shared.table.filter.date_range.to_only", date: format_date(to))
      end
    end

    def format_date(value)
      I18n.l(Date.parse(value), format: "%d.%m.%Y")
    rescue ArgumentError, TypeError
      value.to_s
    end
end
