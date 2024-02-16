class Users::RegularAddressFieldsComponent < ApplicationComponent
  def initialize(user:, f:)
    @user = user
    @f = f
  end

  private

    def display_style
      @user.validate_regular_address_fields? ? "block" : "none"
    end
end
