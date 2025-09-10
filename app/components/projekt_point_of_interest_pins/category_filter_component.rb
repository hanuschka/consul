class ProjektPointOfInterestPins::CategoryFilterComponent < ApplicationComponent
  delegate :toggle_element_in_array, to: :helpers

  def initialize(projekt_phase_id:)
    @projekt_phase = ProjektPhase.find(projekt_phase_id)
    @categories = @projekt_phase.projekt_point_of_interest_categories
  end

  def category_selected?(category)
    params[:category_ids].present? && params[:category_ids].include?(category.id.to_s)
  end

  def link_path(category)
    selected_categories = params[:category_ids].to_a
    url_to_footer_tab(remote: true, category_ids: toggle_element_in_array(selected_categories, category.id.to_s))
  end

  def footer_tab_back_button_url(category)
    selected_categories = params[:category_ids].to_a

    if controller_name == "pages" &&
        !helpers.request.path.starts_with?("/projekts")

      url_to_footer_tab(category_ids: toggle_element_in_array(selected_categories, category.id.to_s))
    else
      "empty"
    end
  end

  def category_button_color(category)
    if category_selected?(category)
      category.color
    else
      "gray"
    end
  end
end
