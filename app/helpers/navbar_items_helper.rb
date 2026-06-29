module NavbarItemsHelper
  def navbar_item_url(item)
    case item.kind
    when "presets"
      if item.landing_page.present?
        landing_page_preset_url(item)
      else
        global_preset_url(item)
      end
    when "projekts"
      item.projekt&.url
    when "landing_pages"
      item.linked_page&.url
    when "external"
      item.external_url
    end
  end

  def navbar_item_preset_for_landing_page?(landing_page, preset)
    return false if landing_page.blank?

    NavbarItem.for_landing_page(landing_page.id).where(kind: :presets, preset: preset).exists?
  end

  def navbar_item_link_attrs(item)
    attrs = []
    attrs << ' target="_blank" rel="noopener noreferrer"' if item.open_in_new_tab?
    attrs << ' aria-current="page"' if navbar_item_current?(item)
    attrs.join
  end

  def navbar_item_current?(item)
    return false if item.external?
    return false unless respond_to?(:request) && request.present?

    navbar_item_url(item) == request.path
  end

  def navbar_item_visible?(item, user = current_user)
    return false if item.resource_missing?

    if item.kind == "landing_pages" && !item.linked_page.published?
      return draft_landing_page_visible_in_nav?(item.linked_page, user)
    end

    return true unless item.kind == "projekts"
    return true if user&.administrator?

    visible_projekt_ids_for_navbar(user).include?(item.projekt_id)
  end

  def landing_pages_for_top_nav
    pages = SiteCustomization::Page.landing.landing_show_in_top_nav

    scope =
      if current_user&.administrator? ||
          current_user&.landing_page_manager&.manage_all_landing_pages?
        pages
      elsif current_user&.landing_page_manager.present?
        pages.published.or(
          pages.where(id: current_user.landing_page_manager.landing_page_manager_assignments.select(:page_id))
        )
      else
        pages.published
      end

    scope.order(:landing_nav_position)
  end

  private

  def draft_landing_page_visible_in_nav?(page, user)
    return false if user.blank?

    user.administrator? || user.landing_page_manager?(page)
  end

  def visible_projekt_ids_for_navbar(user)
    @visible_projekt_ids_for_navbar ||= Projekt.visible_for(user).pluck(:id).to_set
  end

  def global_preset_url(item)
    case item.preset
    when "projekts" then projekts_path
    when "events" then projekt_events_path
    when "investments" then investments_path
    when "proposals" then proposals_path
    when "polls" then polls_path
    when "deficiency_reports" then deficiency_reports_path
    when "ideas" then ideas_path
    end
  end

  def landing_page_preset_url(item)
    slug = item.landing_page.slug

    case item.preset
    when "projekts" then landing_page_projekts_path(slug)
    when "events" then landing_page_events_path(slug)
    when "investments" then landing_page_investments_path(slug)
    when "proposals" then landing_page_proposals_path(slug)
    when "polls" then landing_page_polls_path(slug)
    end
  end
end
