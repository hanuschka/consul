module Adm
  class MapLocationsController < Adm::BaseController
    before_action :find_map_location

    def update
      authorize @map_location.mappable, :update?, policy_class: policy_class_for(@map_location.mappable)

      if @map_location.update(map_location_params)
        flash.now[:success] = t("adm.default_map_location.update.success")
      end

      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@map_location, :editor),
        Adm::MapSettingComponent.new(
          map_location: @map_location,
          path: map_location_path_for(@map_location.mappable)
        )
      )
    end

    private

      def find_map_location
        if params[:id]
          @map_location = MapLocation.find(params[:id])
        elsif params[:projekt_id]
          @map_location = Projekt.find(params[:projekt_id]).map_location
        elsif params[:phase_id]
          @map_location = ProjektPhase.find(params[:phase_id]).map_location
        elsif params[:idea_id]
          @map_location = Idea.find(params[:idea_id]).map_location
        end
      end

      def policy_class_for(mappable)
        case mappable
        when Projekt
          Adm::Projekts::ProjektPolicy
        when ProjektPhase
          Adm::Projekts::ProjektPhasePolicy
        when Idea
          Adm::Ideas::IdeaPolicy
        else
          raise ArgumentError, "No policy class defined for #{mappable.class.name}"
        end
      end

      def map_location_path_for(mappable)
        case mappable
        when Projekt
          adm_projekts_projekt_map_location_path(mappable)
        when ProjektPhase
          adm_projekts_phase_map_location_path(mappable)
        when Idea
          adm_ideas_idea_map_location_path(mappable)
        else
          polymorphic_path([:adm, mappable, :map_location])
        end
      end

      def map_location_params
        params.require(:map_location).permit(
          :latitude, :longitude, :altitude, :zoom, :features, :rendering_library, :show_admin_shape
        )
      end
  end
end
