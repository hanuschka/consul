class Debates::NewButtonComponent < ApplicationComponent
  delegate :current_user, :user_signed_in?, :sanitize, :link_to_verify_account, :link_to_signin, :link_to_signup, to: :helpers
  attr_reader :selected_parent_projekt

  def initialize(selected_parent_projekt = nil, current_tab_phase = nil)
    @selected_parent_projekt = selected_parent_projekt
    @current_tab_phase = current_tab_phase
  end

  private

    def any_selectable_projekts?
      if @current_tab_phase.present? && !@selected_parent_projekt.overview_page?
        (@selected_parent_projekt.all_parent_ids + [@selected_parent_projekt.id] +  @selected_parent_projekt.all_children_ids).any? { |id| Projekt.find(id).selectable?('debates', current_user) }
      else
        Projekt.top_level.selectable_in_selector('debates', current_user).any?
      end
    end

    def link_params_hash
      link_params = {}
      link_params[:projekt] = selected_parent_projekt
      link_params[:origin] = 'projekt' if controller_name == 'pages'
      link_params
    end
end