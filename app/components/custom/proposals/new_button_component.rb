class Proposals::NewButtonComponent < ApplicationComponent
  delegate :current_user, :user_signed_in?, :sanitize, :link_to_verify_account, :link_to_signin, :link_to_signup, to: :helpers
  attr_reader :selected_parent_projekt

  def initialize(selected_parent_projekt = nil, current_tab_phase = nil, resources_order = nil)
    @selected_parent_projekt = selected_parent_projekt
    @current_tab_phase = current_tab_phase
    @resources_order = resources_order
  end

  private

    def show_link?
      return true if @selected_parent_projekt&.overview_page?

      any_selectable_projekts?
    end

    def any_selectable_projekts?
      if @current_tab_phase.present?
        (@selected_parent_projekt.all_parent_ids + [@selected_parent_projekt.id] +  @selected_parent_projekt.all_children_ids).any? { |id| Projekt.find(id).selectable?('proposals', current_user) }
      else
        Projekt.top_level.selectable_in_selector('proposals', current_user).any?
      end
    end

    def link_params_hash
      link_params = {}

      link_params[:projekt_id] = selected_parent_projekt.id if selected_parent_projekt.present?
      link_params[:origin] = 'projekt' if controller_name == 'pages'
      link_params[:order] = @resources_order
      link_params
    end
end
