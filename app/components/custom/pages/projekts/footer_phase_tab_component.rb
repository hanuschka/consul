class Pages::Projekts::FooterPhaseTabComponent < ApplicationComponent
  delegate :format_date, :format_date_range, :current_user, :projekt_feature?,
           :phase_user_status_restriction_name, :phase_geo_restriction_name, :phase_age_restriction_name,
           :phase_extended_geozone_restriction_name, :phase_individual_group_value_restriction_name, to: :helpers
  attr_reader :phase, :default_projekt_phase, :resource_count

  def initialize(phase, default_projekt_phase, namespace: nil)
    @phase = phase
    @default_projekt_phase = default_projekt_phase
    @projekt = phase.projekt
    @projekt_tree_ids = @projekt.all_children_ids.unshift(@projekt.id)
    @namespace = namespace
  end

  private

    def tab_url
      additional_params = {}

      projekt_phase_footer_tab_page_path(@projekt.page, phase, **additional_params)
    end

    def additional_classes
      base = ""
      base += " is-active" if phase.id == params[:projekt_phase_id]
      base += " -deactivated" unless phase.active?
      base += " -default-phase" if @default_projekt_phase == phase

      base
    end

    def resource_type
      @phase.resources_name
    end

    def show_send_notification_button?
      [ProjektPhase::ArgumentPhase, ProjektPhase::QuestionPhase].include?(@phase.class)
    end

    def resource_id
      ''
    end

    def phase_edit_url
      action = phase.admin_nav_bar_items.first

      if @namespace == :admin
        helpers.send("#{action}_adm_projekts_phase_path", phase)
      else
        helpers.polymorphic_path([@namespace, phase], action: action)
      end
    end

    def tab_title
      @phase.title
    end
end
