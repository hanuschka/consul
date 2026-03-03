module Adm
  class DefaultMapLocationController < Adm::BaseController
    def show
      authorize [:adm, MapLocation], :update?

      @default_map_location = MapLocation.default
      @breadcrumbs = [
        { name: t("adm.menu.items.application") },
        { name: t(".title") }
      ]
    end

    def update
      authorize [:adm, MapLocation], :update?

      @default_map_location = MapLocation.default
      if @default_map_location.update(map_location_params)
        flash.now[:success] = t(".success")
      end
    end

    private

      def map_location_params
        params.require(:map_location).permit(
          :latitude, :longitude, :altitude, :zoom, :features, :rendering_library
        )
      end
  end
end
