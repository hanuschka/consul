class Debates::NewButtonComponent < ApplicationComponent
  delegate :current_user, to: :helpers
  attr_reader :selected_parent_projekt

  def initialize(selected_parent_projekt = nil, current_tab_phase = nil)
    @selected_parent_projekt = selected_parent_projekt
    @current_tab_phase = current_tab_phase
  end

  private

    def any_selectable_projekts?
      if @current_tab_phase.present?
        @selected_parent_projekt.top_parent.all_children_projekts.unshift(@selected_parent_projekt.top_parent).any? { |p| p.selectable?('debates', current_user) }
      else
        Projekt.top_level.selectable_in_selector('debates', current_user).any?
      end
    end
end
