module Adm
  class ProjektPhasesController < Adm::BaseController
    before_action :find_projekt
    before_action :find_projekt_phase, only: [:update]

    def index
      authorize [:adm, @projekt], :show?
      base_scope = policy_scope([:adm, @projekt.projekt_phases])
        .regular_phases
        .includes(:geozone_restrictions, :age_restriction)
      @projekt_phases = ProjektPhasesQuery.call(base_scope, params)

      @name_header_options = { search: true }

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt.name, url: details_adm_projekt_path(@projekt) },
        { name: t(".title") }
      ]
    end

    def update
      authorize [:adm, @projekt_phase], policy_class: Adm::ProjektPhasePolicy
      @projekt_phase.update(projekt_phase_params)
    end

    private

      def find_projekt
        @projekt = Projekt.find(params[:projekt_id])
      end

      def find_projekt_phase
        @projekt_phase = @projekt.projekt_phases.find(params[:id])
      end

      def projekt_phase_params
        param_key = @projekt_phase.model_name.param_key
        params.require(param_key).permit(:active, :frontend_visibility)
      end
  end
end
