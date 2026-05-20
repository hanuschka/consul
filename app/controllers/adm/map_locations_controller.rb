module Adm
  class MapLocationsController < Adm::BaseController
    MIN_SCREENSHOT_BYTES = 5_000
    ALLOWED_SCREENSHOT_CONTENT_TYPES = ["image/jpeg", "image/png", "image/webp"].freeze

    before_action :find_map_location

    skip_after_action :verify_authorized, only: :update_screenshot

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

    def update_screenshot
      uploaded = params[:screenshot]

      if invalid_screenshot?(uploaded)
        render json: { success: false, errors: ["Screenshot blob missing, too small, or wrong type"] },
               status: :unprocessable_entity
        return
      end

      @map_location.screenshot.attach(uploaded)

      if @map_location.screenshot.attached?
        render json: { success: true }
      else
        render json: { success: false, errors: @map_location.errors.full_messages },
               status: :unprocessable_entity
      end
    end

    private

      def invalid_screenshot?(uploaded)
        return true if uploaded.blank?
        return true if !uploaded.respond_to?(:size)
        return true if uploaded.size < MIN_SCREENSHOT_BYTES
        return true if !valid_screenshot_content_type?(uploaded)

        false
      end

      def valid_screenshot_content_type?(uploaded)
        return false if !uploaded.respond_to?(:content_type)

        ALLOWED_SCREENSHOT_CONTENT_TYPES.include?(uploaded.content_type)
      end

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
          :latitude, :longitude, :altitude, :zoom, :features, :rendering_library, :show_admin_shape, :mapbox_style_id
        )
      end
  end
end
