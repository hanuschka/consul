class Pages::Projekts::FooterPhaseTabComponent < ApplicationComponent
  delegate :format_date, :format_date_range, :get_projekt_phase_restriction_name, :current_user, :projekt_feature?, to: :helpers
  attr_reader :phase, :default_projekt_phase, :resource_count

  def initialize(phase, default_projekt_phase)
    @phase = phase
    @default_projekt_phase = default_projekt_phase
    @projekt = phase.projekt
    @projekt_tree_ids = @projekt.all_children_ids.unshift(@projekt.id)
  end

  private

    def tab_url
      additional_params = {}

      if embedded_and_frame_access_code_valid?(phase.projekt)
        additional_params = { frame_code: params[:frame_code] }
      end

      projekt_phase_footer_tab_page_path(@projekt.page, phase, **additional_params)
    end

    def additional_classes
      base = ""
      base += " is-active" if phase.id == params[:projekt_phase_id]
      base += " -deactivated" unless phase.phase_activated?
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

    def tab_title
      @phase.title
    end
end
