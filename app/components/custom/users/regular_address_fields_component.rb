class Users::RegularAddressFieldsComponent < ApplicationComponent
  def initialize(user:, f:)
    @user = user
    @f = f
  end

  private

    def display_style
      return "none" if first_form_load? && RegisteredAddress.any? && (@user&.registered_address_id.present? || @user&.city_name.blank?)

      @user.validate_regular_address_fields? ? "block" : "none"
    end

    def first_form_load?
      params[:form_registered_address_city_id].nil? &&
        params[:form_registered_address_street_id].nil? &&
        params[:form_registered_address_id].nil?
    end
end
