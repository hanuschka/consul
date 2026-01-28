module Adm
  class MapLocationsController < Adm::BaseController
    before_action :find_map_location

    def update
      authorize [:adm, @map_location.mappable], :update?, policy_class: policy_class_for(@map_location.mappable)

      if @map_location.update(map_location_params)
        flash.now[:success] = t("adm.default_map_location.update.success")
      end

      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@map_location, :editor),
        Adm::MapSettingComponent.new(
          map_location: @map_location,
          path: polymorphic_path([:adm, @map_location.mappable, :map_location])
        )
      )
    end

    private

      def find_map_location
        @map_location = MapLocation.find(params[:id])
      end

      def policy_class_for(mappable)
        case mappable
        when ProjektPhase
          Adm::ProjektPhasePolicy
        end
      end

      def map_location_params
        params.require(:map_location).permit(
          :latitude, :longitude, :altitude, :zoom, :features, :rendering_library, :show_admin_shape
        )
      end
  end
end
