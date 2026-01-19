module Adm
  class ProjektMapLocationsController < Adm::BaseController
    def update
      @projekt = Projekt.find(params[:projekt_id])
      authorize [:adm, @projekt], :update?

      @map_location = @projekt.map_location
      if @map_location.update(map_location_params)
        flash.now[:success] = t("adm.default_map_location.update.success")
      end

      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@map_location, :editor),
        Adm::MapSettingComponent.new(
          map_location: @map_location,
          path: adm_projekt_map_location_path(@projekt)
        )
      )
    end

    private

      def map_location_params
        params.require(:map_location).permit(
          :latitude, :longitude, :altitude, :zoom, :features, :rendering_library, :show_admin_shape
        )
      end
  end
end
