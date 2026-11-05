load Rails.root.join("app", "controllers", "admin", "geozones_controller.rb")

class Admin::GeozonesController < Admin::BaseController
  private

    def allowed_params
      [
        :name, :external_code, :census_code, :html_map_coordinates,
        :postal_codes
      ]
    end
end
