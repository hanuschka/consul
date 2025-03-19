module ProjektPhaseControllerUtils
  extend ActiveSupport::Concern

  included do
    helper_method :next_action_for_phase
    helper_method :previous_action_for_phase
  end

  def next_action_for_phase(projekt_phase, current_action)
    return current_action unless embedded?

    return "naming" if current_action == nil

    current_action_index = projekt_phase.embedded_admin_nav_bar_items.index(current_action)

    return nil if current_action_index.nil?

    next_action_index = current_action_index + 1

    if next_action_index >= projekt_phase.embedded_admin_nav_bar_items.size
      return nil
    end

    projekt_phase.embedded_admin_nav_bar_items[next_action_index]
  end

  def previous_action_for_phase(projekt_phase, current_action)
    return current_action unless embedded?

    current_action_index = projekt_phase.embedded_admin_nav_bar_items.index(current_action)

    if current_action_index.nil? || current_action_index == 0
      return nil
    end

    prev_action_index = current_action_index - 1
    projekt_phase.embedded_admin_nav_bar_items[prev_action_index]
  end
end
