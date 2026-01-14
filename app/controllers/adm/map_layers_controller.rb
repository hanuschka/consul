module Adm
  class MapLayersController < Adm::BaseController
    def new
      @map_layer = MapLayer.new
      authorize [:adm, @map_layer]

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.default_map_location.show.title"), url: adm_default_map_location_path },
        { name: t(".title") }
      ]
    end

    def create
      @map_layer = MapLayer.new(map_layer_params)
      authorize [:adm, @map_layer]

      if @map_layer.save
        redirect_to adm_default_map_location_path, notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @map_layer = MapLayer.find(params[:id])
      authorize [:adm, @map_layer]

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.default_map_location.show.title"), url: adm_default_map_location_path },
        { name: t(".title") }
      ]
    end

    def update
      @map_layer = MapLayer.find(params[:id])
      authorize [:adm, @map_layer]

      if @map_layer.update(map_layer_params)
        redirect_to adm_default_map_location_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @map_layer = MapLayer.find(params[:id])
      authorize [:adm, @map_layer]

      @map_layer.destroy!
      redirect_to adm_default_map_location_path, notice: t(".success")
    end

    private

      def map_layer_params
        params.require(:map_layer).permit(
          :name, :layer_names, :base, :show_by_default,
          :provider, :attribution, :protocol, :transparent, :opacity
        )
      end
  end
end
