module Adm
  class ProjektPhasesController < Adm::BaseController
    before_action :find_projekt, only: [:index, :new, :create]
    before_action :find_projekt_phase, except: [:index, :new, :create]

    def index
      authorize [:adm, @projekt], :show?
      base_scope = policy_scope([:adm, @projekt.projekt_phases])
        .regular_phases
        .includes(:geozone_restrictions, :age_restriction)
      @projekt_phases = ProjektPhasesQuery.call(base_scope, params)

      @name_header_options = { search: true }

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt.name, url: details_adm_projekt_path(@projekt) },
        { name: t(".title") }
      ]
    end

    def new
      authorize [:adm, ProjektPhase], :create?
      @phase_types = ProjektPhase::PROJEKT_PHASES_TYPES

      @breadcrumbs = [
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

      if @projekt_phase.update(projekt_phase_params)
        flash.now[:success] = t("adm.attribute.update.success")
      end

      render turbo_stream: turbo_stream.replace(
        turbo_frame_request_id,
        partial: "adm/projekt_phases/#{frame_partial_path}",
        locals: { projekt_phase: @projekt_phase }
      )
    end

    def duration
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end

    def naming
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end

    def restrictions
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end

    def toggle_active
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @projekt_phase.update(active: !@projekt_phase.active)
    end

    def toggle_frontend_visibility
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @projekt_phase.update(frontend_visibility: !@projekt_phase.frontend_visibility)
    end

    def general_settings
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end

    def form_author
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end

    def user_functions
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end

    # Stub actions - to be implemented
    def settings; end

    def proposals
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy
      @pagy, @proposals = pagy(@projekt_phase.proposals.order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end
    def budget_phases; end
    def budget_edit; end
    def budget_investments; end
    def poll_questions; end
    def formular; end
    def formular_answers; end
    def milestones; end
    def progress_bars; end
    def legislation_process_draft_versions; end
    def map
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy

      @projekt_phase.copy_map_settings_from_projekt unless @projekt_phase.map_location.present?

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end
    def projekt_point_of_interest_categories; end
    def projekt_point_of_interest_pins; end
    def map_resources_overview; end

    def projekt_labels
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy
      @projekt_labels = @projekt_phase.projekt_labels

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end

    def sentiments
      authorize [:adm, @projekt_phase], :update?, policy_class: Adm::ProjektPhasePolicy
      @sentiments = @projekt_phase.sentiments

      @breadcrumbs = [
        { name: t("adm.menu.items.projekts"), url: adm_projekts_path },
        { name: @projekt_phase.projekt.name, url: details_adm_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t(".title") }
      ]
    end

    def officing_managers; end
    def officing_manager_audits; end
    def age_ranges_for_stats; end
    def ai_settings; end
    def projekt_notifications; end
    def projekt_events; end
    def projekt_livestreams; end
    def projekt_questions; end
    def projekt_arguments; end

    private

      def find_projekt
        @projekt = Projekt.find(params[:projekt_id])
      end

      def frame_partial_path
        turbo_frame_request_id&.gsub("__", "/")
      end

      def find_projekt_phase
        if @projekt
          @projekt_phase = @projekt.projekt_phases.find(params[:id])
        else
          @projekt_phase = ProjektPhase.find(params[:id])
        end
      end

      def projekt_phase_params
        filter_empty_registered_address_grouping_restrictions if params.dig(:projekt_phase, :registered_address_grouping_restrictions)

        param_key = @projekt_phase.model_name.param_key
        params.require(param_key).permit(
          :active, :frontend_visibility, :start_date, :end_date,
          :phase_tab_name, :cta_button_name,
          :resource_form_intro, :resource_form_title, :resource_form_title_placeholder,
          :resource_form_description_placeholder, :welcome_text_in_show,
          :labels_name, :sentiments_name,
          :comment_form_title, :comment_form_button,
          :support_button_text, :description,
          :user_status, :age_range_id,
          :geozone_restricted, :registered_address_grouping_restriction,
          registered_address_district_ids: [], registered_address_street_ids: [],
          individual_group_value_ids: [],
          registered_address_grouping_restrictions: registered_address_grouping_restrictions_params
        )
      end

      def registered_address_grouping_restrictions_params
        ::RegisteredAddress::Grouping.pluck(:key).each_with_object({}) do |key, hash|
          hash[key.to_sym] = []
        end
      end

      def filter_empty_registered_address_grouping_restrictions
        grouping_restrictions = params[:projekt_phase][:registered_address_grouping_restrictions]
        return if grouping_restrictions.blank?

        filtered = grouping_restrictions
          .reject { |_, v| v == [""] }
          .as_json
          .each { |_, v| v.reject!(&:blank?) }

        params[:projekt_phase][:registered_address_grouping_restrictions] = filtered
      end

      def create_params
        params.require(:projekt_phase).permit(:projekt_id, :type)
      end
  end
end
