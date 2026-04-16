module Adm
  class MapLayersController < Adm::BaseController
    before_action :find_mappable, only: [:new, :create]

    def new
      @map_layer = MapLayer.new(mappable: @mappable)
      authorize @map_layer, policy_class: policy_class_for(@map_layer)

      @breadcrumbs = breadcrumbs_for(@mappable, t(".title"))
      @back_url = redirect_path_for_mappable(@mappable)
    end

    def create
      @map_layer = MapLayer.new(map_layer_params.merge(mappable: @mappable))
      authorize @map_layer, policy_class: policy_class_for(@map_layer)

      if @map_layer.save
        redirect_to redirect_path_for(@map_layer), notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @map_layer = MapLayer.find(params[:id])
      authorize @map_layer, policy_class: policy_class_for(@map_layer)

      @breadcrumbs = breadcrumbs_for(@map_layer.mappable, t(".title"))
      @back_url = redirect_path_for_mappable(@map_layer.mappable)
    end

    def update
      @map_layer = MapLayer.find(params[:id])
      authorize @map_layer, policy_class: policy_class_for(@map_layer)

      if @map_layer.update(map_layer_params)
        redirect_to redirect_path_for(@map_layer), notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @map_layer = MapLayer.find(params[:id])
      authorize @map_layer, policy_class: policy_class_for(@map_layer)

      redirect_path = redirect_path_for(@map_layer)
      @map_layer.destroy!
      redirect_to redirect_path, notice: t(".success")
    end

    private

      def find_mappable
        if params[:projekt_id]
          @mappable = Projekt.find(params[:projekt_id])
        elsif params[:phase_id]
          @mappable = ProjektPhase.find(params[:phase_id])
        else
          @mappable = nil
        end
      end

      def map_layer_params
        params.require(:map_layer).permit(
          :name, :layer_names, :base, :show_by_default,
          :provider, :attribution, :protocol, :transparent, :opacity
        )
      end

      def policy_class_for(map_layer)
        case map_layer.mappable
        when Projekt, ProjektPhase
          Adm::Projekts::MapLayerPolicy
        else
          Adm::MapLayerPolicy
        end
      end

      def redirect_path_for(map_layer)
        case map_layer.mappable
        when Projekt
          map_adm_projekts_projekt_path(map_layer.mappable)
        when ProjektPhase
          map_adm_projekts_phase_path(map_layer.mappable)
        else
          adm_default_map_location_path
        end
      end

      def breadcrumbs_for(mappable, title)
        case mappable
        when Projekt
          [
            { name: t("adm.projekts.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
            { name: mappable.name, url: details_adm_projekts_projekt_path(mappable) },
            { name: t("adm.projekts.projekts.tabs.map"), url: map_adm_projekts_projekt_path(mappable) },
            { name: title }
          ]
        when ProjektPhase
          [
            { name: t("adm.projekts.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
            { name: mappable.projekt.name, url: details_adm_projekts_projekt_path(mappable.projekt) },
            { name: mappable.title },
            { name: t("adm.projekts.phases.projekt_phase.map"), url: map_adm_projekts_phase_path(mappable) },
            { name: title }
          ]
        else
          [
            { name: t("adm.menu.items.application"), icon: "desktop_windows" },
            { name: t("adm.default_map_location.show.title"), url: adm_default_map_location_path },
            { name: title }
          ]
        end
      end

      def redirect_path_for_mappable(mappable)
        case mappable
        when Projekt then map_adm_projekts_projekt_path(mappable)
        when ProjektPhase then map_adm_projekts_phase_path(mappable)
        else adm_default_map_location_path
        end
      end
  end
end
