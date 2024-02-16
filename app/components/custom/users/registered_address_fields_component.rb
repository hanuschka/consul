class Users::RegisteredAddressFieldsComponent < ApplicationComponent
  def initialize(resource: nil, selected_city_id: nil, selected_street_id: nil, selected_address_id: nil)
    @resource = resource
    @selected_city_id = selected_city_id
    @selected_street_id = selected_street_id
    @selected_address_id = selected_address_id
  end

  def render?
    RegisteredAddress.any?
  end

  private

    def options_for_city_select
      RegisteredAddress::City.all
        .map { |city| [city.name, city.id] }
        .push([t("custom.helpers.select.not_in_list"), 0])
    end

    def selected_city
      RegisteredAddress::City.find_by(id: @selected_city_id)
    end

    def options_for_street_select
      return [] unless @selected_city_id.present?

      selected_city.registered_address_streets
        .map { |str| [str.name_with_plz, str.id] }
        .push([t("custom.helpers.select.not_in_list"), 0])
    end

    def selected_street
      RegisteredAddress::Street.find_by(id: @selected_street_id)
    end

    def options_for_address_select
      return [] unless selected_street.present?

      selected_street.registered_addresses
        .sort_by { |adr| [adr.street_number.to_i, adr.street_number_extension.to_s] }
        .map { |adr| [adr.formatted_name, adr.id] }
        .push([t("custom.helpers.select.not_in_list"), 0])
    end

    def selected_address
      RegisteredAddress.find_by(id: @selected_address_id)
    end

    def highlight_error?(field)
      @resource.present? && @resource.errors[:registered_address_id].present? && field.nil?
    end
end
