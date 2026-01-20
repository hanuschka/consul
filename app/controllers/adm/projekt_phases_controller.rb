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

    def new
      authorize [:adm, ProjektPhase], :create?
      @phase_types = ProjektPhase::PROJEKT_PHASES_TYPES

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt.name },
        { name: t("adm.projekt_phases.index.title"), url: adm_projekt_projekt_phases_path(@projekt) },
        { name: t(".title") }
      ]
    end

    def create
      authorize [:adm, ProjektPhase], :create?
      @projekt_phase = ProjektPhase.new(create_params.merge(active: true))

      if @projekt_phase.save
        redirect_to adm_projekt_projekt_phases_path(@projekt), notice: t(".success")
      else
        redirect_to new_adm_projekt_projekt_phase_path(@projekt), alert: @projekt_phase.errors.full_messages.join(", ")
      end
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

      def create_params
        params.require(:projekt_phase).permit(:projekt_id, :type)
      end
  end
end
