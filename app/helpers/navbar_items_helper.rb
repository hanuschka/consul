module NavbarItemsHelper
  def navbar_item_url(item)
    case item.kind
    when "presets"
      public_send(NavbarItem::PRESETS[item.preset.to_sym])
    when "projekts"
      item.projekt.page.url
    when "external"
      item.external_url
    end
  end

  def navbar_item_link_attrs(item)
    item.external? ? ' target="_blank" rel="noopener noreferrer"' : ''
  end
end
