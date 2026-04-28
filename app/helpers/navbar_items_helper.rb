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
    attrs << ' target="_blank" rel="noopener noreferrer"' if item.external?
    attrs << ' aria-current="page"' if navbar_item_current?(item)
    attrs.join
  end

  def navbar_item_current?(item)
    return false if item.external?
    return false unless respond_to?(:request) && request.present?

    navbar_item_url(item) == request.path
  end

  private

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
