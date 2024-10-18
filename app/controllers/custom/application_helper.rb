require_dependency Rails.root.join("app", "helpers", "application_helper").to_s

module ApplicationHelper
  def url_to_footer_tab(
    remote: false,
    pagination_page: nil,
    filter: nil,
    order: nil,
    projekt_label_ids: nil,
    sentiment_id: nil,
    section: nil,
    extras: {}
  )
    return "" unless params[:projekt_phase_id].present?

    projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    url_options = {
      page: pagination_page || params[:page],
      filter: filter || params[:filter],
      order: order || params[:order],
      projekt_label_ids: projekt_label_ids || params[:projekt_label_ids],
      sentiment_id: sentiment_id || params[:sentiment_id],
      section: section || params[:section],
      annotation_id: params[:annotation_id]
    }

    url_options.reject! { |k, v| k == :sentiment_id && v == 0 }

    if remote
      projekt_phase_footer_tab_page_path(projekt_phase.projekt.page, projekt_phase.id, **url_options, **extras)
    else
      page_path(projekt_phase.projekt.page.slug, projekt_phase_id: projekt_phase.id, **url_options, **extras)
    end
  end

  def projekt_footer_phase_filter_url(projekt_phase)
    projekt_phase_footer_tab_page_path(projekt_phase.projekt.page, projekt_phase.id)
  end

  def page_entries_info(collection, entry_name: nil)
    records = collection.respond_to?(:records) ? collection.records : collection.to_a
    page_size = records.size
    entry_name = if entry_name
                   entry_name.pluralize(page_size, I18n.locale)
                 else
                   collection.entry_name(count: page_size)
                 end

    if collection.total_pages < 2
      t('helpers.page_entries_info.one_page.display_entries', entry_name: entry_name, count: collection.total_count)
    else
      from = collection.offset_value + 1
      to =
        if collection.is_a? ::Kaminari::PaginatableArray
          [collection.offset_value + collection.limit_value, collection.total_count].min
        else
          collection.offset_value + page_size
        end

      t('helpers.page_entries_info.more_pages.display_entries', entry_name: entry_name, first: from, last: to, total: collection.total_count)
    end.html_safe
  end
end
