class Kern::RegularAddressFieldsComponent < ApplicationComponent
  def initialize(user:, f:)
    @user = user
    @f = f
  end

  private

    def display_style
      return "block" if RegisteredAddress.none?

      if first_form_load?
        @user&.registered_address_id.blank? && @user&.city_name.present? ? "block" : "none"
      else
        not_in_list_selected? ? "block" : "none"
      end
    end

    def not_in_list_selected?
      [params[:form_registered_address_city_id],
       params[:form_registered_address_street_id],
       params[:form_registered_address_id]].include?("0")
    end

    def first_form_load?
      params[:form_registered_address_city_id].nil? &&
        params[:form_registered_address_street_id].nil? &&
        params[:form_registered_address_id].nil?
    end
end
