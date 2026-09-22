class Adm::MunicipalPlansQuery < ApplicationQuery
  SORTABLE_FIELDS = %i[content_updated_at version status].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  # The shared filters are expressed in the public query's vocabulary; the administration table
  # names its parameters differently, so they are translated before delegating.
  def call
    ::MunicipalPlansQuery.new(base_scope, shared_filter_params)
      .call
      .then { |r| apply_status(r) }
      .then { |r| apply_responsible(r) }
      .then { |r| apply_title_search(r) }
      .then { |r| apply_sorting(r) }
  end

  private

    attr_reader :base_scope, :params

    def shared_filter_params
      {
        districts: params[:districts],
        topics: params[:topics],
        participation: params[:participation],
        recency: params[:recency],
        updated_from: params["content_updated_at__from"],
        updated_to: params["content_updated_at__to"]
      }
    end

    def apply_status(scope)
      values = Array(params[:status]).map(&:to_s) & MunicipalPlan::STATUSES
      return scope if values.empty?

      scope.where(status: values)
    end

    def apply_responsible(scope)
      pairs = Array(params[:responsible]).map { |value| value.to_s.split(":") }
                                         .select { |type, id| responsible_pair?(type, id) }
      return scope if pairs.empty?

      table = scope.klass.arel_table
      conditions = pairs.map do |type, id|
        table[:responsible_type].eq("MunicipalPlan::#{type}").and(table[:responsible_id].eq(id.to_i))
      end

      scope.where(conditions.reduce(:or))
    end

    def responsible_pair?(type, id)
      %w[Officer OfficerGroup].include?(type) && id.to_s.match?(/\A\d+\z/)
    end

    def apply_title_search(scope)
      value = params[:title__search]
      return scope if value.blank?

      scope.where(id: MunicipalPlan.translation_class
                        .where("title ILIKE ?", "%#{escape_like(value)}%")
                        .select(:municipal_plan_id))
    end

    def apply_sorting(scope)
      field = params[:sort_by]&.to_sym
      return scope.sorted unless SORTABLE_FIELDS.include?(field)

      direction = params[:sort_direction].to_s.casecmp("desc").zero? ? "DESC" : "ASC"
      return scope.reorder(Arel.sql(version_order(direction))) if field == :version

      scope.reorder(field => direction.downcase.to_sym)
    end

    # Versionsnummer is a string, so a plain sort puts 1.10 before 1.2. Both parts sort numerically.
    def version_order(direction)
      "split_part(version, '.', 1)::int #{direction}, split_part(version, '.', 2)::int #{direction}"
    end
end
