module Adm
  class DeficiencyReportsQuery < ApplicationQuery
    SEARCHABLE_FIELDS = %i[id title approximated_address].freeze
    SORTABLE_FIELDS = %i[id created_at updated_at status_changed_at].freeze
    FILTERABLE_FIELDS = %i[
      deficiency_report_category_id
      deficiency_report_subcategory_id
      deficiency_report_status_id
      deficiency_report_intake_channel_id
      responsible
      archived_state
      hidden_state
      district
      assignment_scope
    ].freeze
    DATE_RANGE_FIELDS = %i[created_at updated_at status_changed_at].freeze

    def initialize(base_scope, params = {}, current_user: nil)
      @base_scope = base_scope
      @params = params
      @current_user = current_user
    end

    def call
      base_scope
        .then { |r| apply_search(r) }
        .then { |r| apply_filters(r) }
        .then { |r| apply_date_ranges(r) }
        .then { |r| apply_sorting(r) }
        .distinct
    end

    private

      attr_reader :base_scope, :params, :current_user

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
        scope = apply_id_search(scope)
        scope = apply_title_search(scope)
        scope = apply_address_search(scope)
        apply_author_search(scope)
      end

      def apply_id_search(scope)
        value = params[:id__search]
        return scope if value.blank?
        return scope unless value.to_s.match?(/\A\d+\z/)

        scope.where(id: value)
      end

      def apply_title_search(scope)
        value = params[:title__search]
        return scope if value.blank?

        pattern = "%#{escape_like(value)}%"
        scope.joins(:translations).where(
          "deficiency_report_translations.title ILIKE :p OR deficiency_report_translations.description ILIKE :p",
          p: pattern
        )
      end

      def apply_address_search(scope)
        value = params[:approximated_address__search]
        return scope if value.blank?

        scope.joins(:map_location).where(
          "map_locations.approximated_address ILIKE ?", "%#{escape_like(value)}%"
        )
      end

      def apply_author_search(scope)
        value = params[:author__search]
        return scope if value.blank?

        scope.joins(:author).where("users.username ILIKE ?", "%#{escape_like(value)}%")
      end

      def apply_filters(scope)
        permitted = filterable_params
        permitted[:archived_state] ||= []
        permitted[:hidden_state] ||= []

        permitted.each do |field, values|
          scope = case field
                  when :archived_state then filter_by_archived_state(scope, values)
                  when :hidden_state   then filter_by_hidden_state(scope, values)
                  when :responsible    then filter_by_responsible(scope, values)
                  when :district       then filter_by_district(scope, values)
                  when :assignment_scope then filter_by_assignment_scope(scope, values)
                  else
                    values.blank? ? scope : scope.where(field => values)
                  end
        end
        scope
      end

      def filter_by_district(scope, values)
        values = Array(values).compact_blank.map(&:to_i).reject(&:zero?)
        return scope if values.empty?

        scope.joins(:map_location).where(map_locations: { registered_address_district_id: values })
      end

      # "Mir zugewiesen" / "Unter Beobachtung" / "Alle Anliegen". Only offered while the visibility
      # setting is on; without it the scope is already narrowed to the officer's own Anliegen and the
      # three values would have nothing to choose between.
      def filter_by_assignment_scope(scope, values)
        values = Array(values).compact_blank.map(&:to_s)
        return scope if values.empty? || values.include?("all")

        officer = current_user&.deficiency_report_officer
        subscopes = []
        subscopes << scope.assigned_to_officer(officer) if values.include?("assigned_to_me") && officer
        subscopes << scope.watched_by(current_user) if values.include?("watching")

        return scope if subscopes.empty?

        subscopes.reduce { |combined, subscope| combined.or(subscope) }
      end

      def filter_by_archived_state(scope, values)
        values = Array(values).compact_blank.map(&:to_s)
        return scope if values.empty?
        return scope if values.include?("active") && values.include?("archived")
        return scope.not_archived if values == ["active"]
        return scope.archived if values == ["archived"]

        scope
      end

      def filter_by_hidden_state(scope, values)
        values = Array(values).compact_blank.map(&:to_s)
        return scope.with_hidden if values.empty?
        return scope.with_hidden if values.include?("visible") && values.include?("hidden")
        return scope.only_hidden if values == ["hidden"]
        return scope if values == ["visible"]

        scope
      end

      def apply_date_ranges(scope)
        table = scope.klass.table_name
        DATE_RANGE_FIELDS.each do |field|
          from = safe_parse_date(params["#{field}__from"])
          to = safe_parse_date(params["#{field}__to"])
          scope = scope.where("#{table}.#{field} >= ?", from.beginning_of_day) if from
          scope = scope.where("#{table}.#{field} <= ?", to.end_of_day) if to
        end
        scope
      end

      def safe_parse_date(value)
        return nil if value.blank?

        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def apply_sorting(scope)
        field = params[:sort_by]&.to_sym
        return scope.order(id: :desc) unless sortable_fields.include?(field)

        direction = params[:sort_direction]&.downcase
        direction = %w[asc desc].include?(direction) ? direction : "asc"

        scope.reorder(field => direction)
      end

      def filter_by_responsible(scope, values)
        values = Array(values).compact_blank
        return scope if values.empty?

        grouped = values.each_with_object({}) do |value, acc|
          type, id = value.to_s.split("_", 2)
          next unless id.present? && %w[Officer OfficerGroup].include?(type)

          acc["DeficiencyReport::#{type}"] ||= []
          acc["DeficiencyReport::#{type}"] << id
        end
        return scope if grouped.empty?

        clauses = grouped.map { "(responsible_type = ? AND responsible_id IN (?))" }
        args = grouped.flat_map { |type, ids| [type, ids] }
        scope.where(clauses.join(" OR "), *args)
      end
  end
end
