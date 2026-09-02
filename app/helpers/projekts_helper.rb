module ProjektsHelper
  def breadcrumbs_links(base_projekt, divider = '/', home_page_link = true)
    divider_tag = content_tag(:span, " #{divider} ", class: 'breadcrumbs-divider', "aria-hidden": "true")

    items = []

    if home_page_link
      items << link_to(t('custom.projekt.page.breadcrumbs.homepage'), root_path, class: 'breadcrumbs-item')
    end

    base_projekt.breadcrumb_trail.each do |projekt|
      if !projekt.page.published? || (projekt == base_projekt && home_page_link)
        items << content_tag(:span, projekt.title, class: 'breadcrumbs-item', "aria-current": "page")
      else
        items << link_to(projekt.page.title, projekt.page.url, class: 'breadcrumbs-item')
      end
    end

    list_items = items.each_with_index.map do |item, index|
      li_content = index > 0 ? (divider_tag + item) : item
      content_tag(:li, li_content, class: 'breadcrumbs-list-item')
    end

    list = content_tag(:ol, safe_join(list_items), class: 'breadcrumbs-list')
    content_tag(:nav, list, class: 'custom-breadcrumbs', "aria-label": "Breadcrumb")
  end

  def projekt_filter_resources_name
    @projekt_phase&.resources_name || controller_name
  end

  def show_archived_projekts_in_sidebar?
    true
  end

  def show_affiliation_filter_in_sidebar?
    Setting["extended_feature.modulewide.show_affiliation_filter_in_index_sidebar"].present? ? true : false
  end

  def prepare_projekt_name(projekt, placement = nil)
    classes = []

    url = projekt.page.url

    if projekt.page.published? && placement == "desktop"
      link_to projekt.page.title, url, class: classes.join(" "), data: { turbolinks: false }
    elsif projekt.page.published? && placement == "mobile"
      link_to projekt.page.title, url, class: classes.join(" ")
    else
      projekt.page.title
    end
  end

  def debates_overview_link(anchor_text, projekt, class_name)
    link_to anchor_text, (debates_path + "?#{projekt.all_children_ids.unshift(projekt.id).to_query('filter_projekt_ids')}"), class: (class_name + ' js-reset-projekt-filter-toggle-status'), data: { projekts: projekt.all_parent_ids.push(projekt.id).join(','), resources: 'debates' }
  end

  def proposals_overview_link(anchor_text, projekt, class_name)
    link_to anchor_text, (proposals_path + "?#{projekt.all_children_ids.unshift(projekt.id).to_query('filter_projekt_ids')}"), class: (class_name + ' js-reset-projekt-filter-toggle-status'), data: { projekts: projekt.all_parent_ids.push(projekt.id).join(','), resources: 'proposals' }
  end

  def polls_overview_link(anchor_text, projekt, class_name)
    link_to anchor_text, (polls_path + "?#{projekt.all_children_ids.unshift(projekt.id).to_query('filter_projekt_ids')}"), class: (class_name + ' js-reset-projekt-filter-toggle-status'), data: { projekts: projekt.all_parent_ids.push(projekt.id).join(','), resources: 'polls' }
  end

  def projekt_phase_active?(projekt, phase_name)
    projekt.send(phase_name).active
  end

  def projekt_phase_not_started_yet?(projekt, phase_name)
    projekt.send(phase_name).start_date > Date.today if projekt.send(phase_name).start_date
  end

  def projekt_phase_expired?(projekt, phase_name)
    projekt.send(phase_name).end_date < Date.today if projekt.send(phase_name).end_date
  end

  def format_date(date)
    return '' if date.blank?
    l(date.to_date, format: :long)
  end

  def format_date_range(start_date=nil, end_date=nil, options={})
    options[:separator] ||= '-'
    options[:separator] = ' ' + options[:separator] + ' '
    options[:prefix].present? ? options[:prefix] = options[:prefix] + ' ' : options[:prefix] = ''

    # if start_date && end_date
    #   options[:prefix] + format_date(start_date) + options[:separator] + format_date(end_date)
    # elsif start_date && !end_date
    #  "Start #{format_date(start_date)}"
    # elsif !start_date && end_date
    #  "bis #{format_date(end_date)}"
    # else
    #  'Zeitlich nicht beschränkt'
    # end

    if end_date.present? && end_date.to_date < Date.today
      t("custom.shared.dates.ends_on", date: l(end_date.to_date, format: :long))
    elsif end_date.present?  && end_date.to_date > Date.today && start_date.present? && start_date.to_date <= Date.today
      days_left = (end_date.to_date - Date.today).to_i
      t('custom.shared.dates.days_left', count: days_left)
    elsif end_date.present? && end_date.to_date == Date.today && start_date.present? && start_date.to_date <= Date.today
      t("custom.shared.dates.ends_today")
    elsif start_date.present? && start_date.to_date > Date.today
      days_left = (start_date.to_date - Date.today).to_i
      t('custom.shared.dates.starts_in_days', count: days_left)
    end
  end

  def format_budget_phase_duration(phase)
    now = Time.zone.now
    starts_at = phase.starts_at
    ends_at   = phase.ends_at

    if ends_at.present? && ends_at <= now
      last_active_day = (ends_at - 1.second).to_date
      t("custom.shared.dates.ends_on", date: l(last_active_day, format: :long))
    elsif ends_at.present? && starts_at.present? && starts_at <= now
      last_active_day = (ends_at - 1.second).to_date
      if last_active_day == now.to_date
        t("custom.shared.dates.ends_today")
      else
        t("custom.shared.dates.days_left", count: (last_active_day - now.to_date).to_i + 1)
      end
    elsif starts_at.present? && starts_at > now
      t("custom.shared.dates.starts_in_days", count: (starts_at.to_date - now.to_date).to_i)
    end
  end

  def get_projekt_phase_duration(phase)
    if phase
      format_date_range(phase.start_date, phase.end_date)
    else
      format_date_range
    end
  end

  def get_projekt_affiliation_name(projekt, only_name = false )
    affiliation_name = projekt.geozone_affiliated || "no_affiliation"
    district_affiliations = projekt.registered_address_district_affiliations

    if district_affiliations.exists? && affiliation_name == 'only_geozones'
      return district_affiliations.pluck(:name).join(', ')
    end

    return affiliation_name if only_name

    t("custom.geozones.projekt_selector.affiliations.#{affiliation_name}" )
  end

  def options_for_projekt_select
    select_options = []

    Projekt.regular.top_level.each do |top_level_projekt|
      select_options += top_level_projekt.all_children_projekts.unshift(top_level_projekt).pluck(:name, :id)
    end

    select_options
  end
end
