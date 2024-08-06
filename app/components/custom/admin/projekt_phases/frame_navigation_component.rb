class Admin::ProjektPhases::FrameNavigationComponent < ApplicationComponent
  def initialize(projekt_phase: nil, hide_prev_next: false, use_link_for_next: false, projekt: nil)
    @projekt_phase = projekt_phase
    @use_link_for_next = use_link_for_next
    @projekt = projekt
    @hide_prev_next = hide_prev_next
  end

  def next_page_url
    return if @projekt_phase.nil?

    next_action = helpers.next_action_for_phase(@projekt_phase, params[:action])

    if next_action.present?
      url_for(action: next_action, action_name: next_action)
    else
      projekt_url
    end
  end

  def previous_page_url
    previous_action = nil

    if @projekt_phase.present?
      previous_action = helpers.previous_action_for_phase(@projekt_phase, params[:action])
    end

    if previous_action.present?
      url_for(action: previous_action)
    else
      projekt_url
    end
  end

  def projekt_url
    projekt.frame_url
  end

  def projekt
    if @projekt_phase.present?
      @projekt_phase.projekt
    elsif @projekt.present?
      @projekt
    end
  end

  def cancel_url
    admin_frame_new_phase_selector_path(projekt)
  end
end
