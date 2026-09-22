class MunicipalPlansQuery < ApplicationQuery
  PARTICIPATION_KINDS = %w[formal informal].freeze
  RECENCY_VALUES = %w[new updated].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  # Values within one filter widen the result (OR), filters combine to narrow it (AND).
  def call
    base_scope
      .then { |r| apply_districts(r) }
      .then { |r| apply_topics(r) }
      .then { |r| apply_participation(r) }
      .then { |r| apply_recency(r) }
      .then { |r| apply_updated_range(r) }
  end

  private

    attr_reader :base_scope, :params

    def apply_districts(scope)
      ids = integer_values(:districts)
      return scope if ids.empty?

      scope.where(id: MunicipalPlan::DistrictAssignment.where(registered_address_district_id: ids)
                                                       .select(:municipal_plan_id))
    end

    def apply_topics(scope)
      ids = integer_values(:topics)
      return scope if ids.empty?

      scope.where(id: MunicipalPlan::TopicAssignment.where(municipal_plan_topic_id: ids)
                                                    .select(:municipal_plan_id))
    end

    def apply_participation(scope)
      kinds = Array(params[:participation]).map(&:to_s) & PARTICIPATION_KINDS
      return scope if kinds.empty?

      table = scope.klass.arel_table
      scope.where(kinds.map { |kind| table["#{kind}_participation"].eq(true) }.reduce(:or))
    end

    def apply_recency(scope)
      values = Array(params[:recency]).map(&:to_s) & RECENCY_VALUES
      return scope if values.empty?

      table = scope.klass.arel_table
      scope.where(values.map { |value| recency_condition(table, value) }.reduce(:or))
    end

    def recency_condition(table, value)
      created_cutoff = MunicipalPlan::RECENCY_WINDOW.ago
      return table[:created_at].gteq(created_cutoff) if value == "new"

      table[:content_updated_at].gteq(Date.current - MunicipalPlan::RECENCY_WINDOW.in_days.to_i)
           .and(table[:created_at].lt(created_cutoff))
    end

    # A plan without an Aktualisierungsdatum matches no date range, which is why each bound is
    # applied on its own rather than through an infinite one.
    def apply_updated_range(scope)
      from = parse_date(params[:updated_from])
      to = parse_date(params[:updated_to])

      scope = scope.where(content_updated_at: from..) if from
      scope = scope.where(content_updated_at: ..to) if to
      scope
    end

    def integer_values(key)
      Array(params[key]).flat_map { |value| value.to_s.split(",") }
                        .map(&:strip).grep(/\A\d+\z/).map(&:to_i).uniq
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
end
