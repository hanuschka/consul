class ProjektsQuery < ApplicationQuery
  SEARCHABLE_FIELDS = %i[name].freeze
  SORTABLE_FIELDS = %i[name total_duration_start total_duration_end].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
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
end
