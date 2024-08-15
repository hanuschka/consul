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

    def additional_classes
      base = ""
      base += " is-active" if phase.id == params[:projekt_phase_id]
      base += " -deactivated" unless phase.phase_activated?
      base += " -default-phase" if @default_projekt_phase == phase

      base
    end

    def tab_title
      @phase.title
    end
end
