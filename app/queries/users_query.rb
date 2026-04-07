class UsersQuery < ApplicationQuery
  SEARCHABLE_FIELDS = %i[username email first_name last_name].freeze
  FILTERABLE_FIELDS = %i[gender reverify document_type].freeze
  SORTABLE_FIELDS = %i[username city_name created_at verified_at].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |r| apply_filters(r) }
      .then { |r| apply_search(r) }
      .then { |r| apply_sorting(r) }
  end

  private

    attr_reader :base_scope, :params

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
