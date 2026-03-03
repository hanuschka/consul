class RegisteredAddressesQuery < ApplicationQuery
  FILTERABLE_FIELDS = %i[registered_address_city_id registered_address_district_id].freeze
  SORTABLE_FIELDS = %i[street_number registered_address_city_id street_name registered_address_district_id].freeze
  SEARCHABLE_FIELDS = %i[street_name].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |r| apply_joins(r) }
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

    def apply_joins(scope)
      scope
        .joins(:registered_address_city)
        .joins(:registered_address_street)
        .left_joins(:district)
    end

    def apply_sorting(scope)
      field = params[:sort_by]&.to_sym
      return scope unless sortable_fields.include?(field)

      direction = params[:sort_direction]&.downcase
      direction = %w[asc desc].include?(direction) ? direction : "asc"

      case field
      when :registered_address_city_id
        scope.order("registered_address_cities.name #{direction}")
      when :street_name
        scope.order("registered_address_streets.name #{direction}")
      when :registered_address_district_id
        scope.order("registered_address_districts.name #{direction} NULLS LAST")
      when :street_number
        scope.order(Arel.sql("CAST(registered_addresses.street_number AS INTEGER) #{direction}, COALESCE(registered_addresses.street_number_extension, '') #{direction}"))
      else
        scope.order(field => direction)
      end
    end

    def apply_search(scope)
      street_name_search = params[:street_name__search]
      return scope if street_name_search.blank?

      scope.where(
        "registered_address_streets.name ILIKE ?",
        "%#{escape_like(street_name_search)}%"
      )
    end
end
