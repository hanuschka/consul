class UsersQuery < ApplicationQuery
  SEARCHABLE_FIELDS = %i[username email first_name last_name].freeze
  FILTERABLE_FIELDS = %i[gender reverify document_type].freeze
  SORTABLE_FIELDS = %i[username city_name created_at verified_at].freeze
  STATUSES = %w[confirmed unconfirmed hidden].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |r| apply_filters(r) }
      .then { |r| apply_status_filter(r) }
      .then { |r| apply_search(r) }
      .then { |r| apply_sorting(r) }
  end

  private

    attr_reader :base_scope, :params

    def apply_status_filter(scope)
      values = Array(params[:status]).map(&:to_s) & STATUSES
      return scope if values.empty? || values.size == STATUSES.size

      table = scope.klass.arel_table
      scope.where(values.map { |value| status_condition(table, value) }.reduce(:or))
    end

    def status_condition(table, value)
      case value
      when "hidden"
        table[:hidden_at].not_eq(nil)
      when "unconfirmed"
        table[:hidden_at].eq(nil).and(table[:confirmed_at].eq(nil))
      else
        table[:hidden_at].eq(nil).and(table[:confirmed_at].not_eq(nil))
      end
    end

    def sortable_fields
      SORTABLE_FIELDS
    end

    def searchable_fields
      SEARCHABLE_FIELDS
    end

    def filterable_fields
      FILTERABLE_FIELDS
    end
end
