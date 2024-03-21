module HasRegisteredAddress
  extend ActiveSupport::Concern

  private

    def process_temp_attributes_for(resource)
      resource.form_registered_address_city_id = params[:form_registered_address_city_id]
      resource.form_registered_address_street_id = params[:form_registered_address_street_id]
      resource.form_registered_address_id = params[:form_registered_address_id]

      signal_values = ["0", ""]

      if [params[:form_registered_address_city_id],
          params[:form_registered_address_street_id],
          params[:form_registered_address_id]].any? { |v| v.in?(signal_values) }
        resource.registered_address_id = nil
      end
    end

    def set_address_attributes
      if params[:form_registered_address_id].present? && params[:form_registered_address_id] != "0"
        registered_address = RegisteredAddress.find(params[:form_registered_address_id])
        params[:user][:registered_address_id] = registered_address.id

        params[:user][:city_name] = registered_address.registered_address_city.name
        params[:user][:plz] = registered_address.registered_address_street.plz
        params[:user][:street_name] = registered_address.registered_address_street.name
        params[:user][:street_number] = registered_address.street_number
        params[:user][:street_number_extension] = registered_address.street_number_extension
      end
    end
end
