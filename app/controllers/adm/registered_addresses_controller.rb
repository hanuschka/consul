module Adm
  class RegisteredAddressesController < Adm::BaseController
    def index
      authorize [:adm, ::RegisteredAddress]
      base_scope = RegisteredAddressesQuery.call(policy_scope([:adm, ::RegisteredAddress]), params)

      @pagy, @registered_addresses = pagy(base_scope, limit: 20)

      setup_header_options

      @breadcrumbs = [
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.registered_addresses") }
      ]
    end

    private

      def setup_header_options
        @city_header_options = {}
        @district_header_options = {}
        @street_name_header_options = { sort: true, search: true }
        @street_number_header_options = { sort: true }

        cities = ::RegisteredAddress::City.distinct.pluck(:id, :name)
        if cities.size > 1
          @city_header_options[:sort] = true
          @city_header_options[:filter_options] = cities.to_h { |id, name| [id, name] }
        end

        districts = ::RegisteredAddress::District.distinct.pluck(:id, :name)
        if districts.size > 1
          @district_header_options[:sort] = true
          @district_header_options[:filter_options] = districts.to_h { |id, name| [id, name] }
        end
      end
  end
end
