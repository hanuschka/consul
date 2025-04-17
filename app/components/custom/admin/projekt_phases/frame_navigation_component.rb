class Admin::ProjektPhases::FrameNavigationComponent < ApplicationComponent
  def initialize(projekt_phase: nil, projekt: nil, show_title: false)
    @projekt_phase = projekt_phase
    @projekt = projekt
    @show_title = show_title
    @previous_page_is_projekt_page = false
    @next_page_is_projekt_page = false
  end

  def next_page_url
    return if @projekt_phase.nil?

    current_action = params[:category].presence || params[:action]
    next_action = helpers.next_action_for_phase(@projekt_phase, current_action)

    if next_action.present?
      url_for(
        action: next_action, action_name: next_action,
        params: {
          category: original_action
        }
      )
    else
      @next_page_is_projekt_page = true
      projekt_url
    end
  end

  def previous_page_url
    previous_action = nil

    current_action = params[:category].presence || params[:action]

    if @projekt_phase.present?
      previous_action = helpers.previous_action_for_phase(@projekt_phase, current_action)
    end

    if previous_action.present?
      url_for(action: previous_action,
        params: {
          category: original_action
        }
      )
    else
      @previous_page_is_projekt_page = true
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
    if current_user.administrator?
      frame_new_phase_selector_admin_projekt_phase(projekt)
    elsif current_user.projekt_manager?
      frame_new_phase_selector_projekt_management_projekt_phase(projekt)
    end
  end
end
