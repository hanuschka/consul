class Projekts::BannerComponent < ApplicationComponent
  def initialize(custom_page:, compact: false)
    @custom_page = custom_page
    @projekt = custom_page.projekt
    @compact = compact
  end

  def show_admin_controls?
    return false if @compact

    @show_admin_controls ||= show_admin_controls_for_projekt?(@projekt)
  end

  def ai_available?
    Ai::Settings.ai_available?
  end

  def generate_image_tooltip_title
    if ai_available?
      I18n.t("custom.projekts.banner_upload.generate_tooltip_title")
    else
      I18n.t("custom.projekts.banner_upload.generate_disabled_tooltip_title")
    end
  end

  def generate_image_tooltip_text
    if ai_available?
      I18n.t("custom.projekts.banner_upload.generate_tooltip_text")
    else
      I18n.t("custom.projekts.banner_upload.generate_disabled_tooltip_text")
    end
  end

  def banner_image_size_hint
    I18n.t("custom.projekts.banner_upload.min_image_size_hint", width: 590, height: 355)
  end

  def banner_ai_generated?
    @custom_page.image&.ai_generated? == true
  end

  def ai_marker_tooltip_title
    I18n.t("custom.projekts.banner_upload.ai_marker_tooltip_title")
  end

  def ai_marker_tooltip_text
    I18n.t("custom.projekts.banner_upload.ai_marker_tooltip_text")
  end

  def ai_marker_tooltip_note
    I18n.t("custom.projekts.banner_upload.ai_marker_tooltip_note")
  end

  def banner_wrapper_class
    classes = ["custom-page--banner-wrapper"]
    classes << "-compact" if @compact
    classes.join(" ")
  end

  def show_meta_chips?
    return false if @compact
    return false unless @projekt.present?

    start_date_chip_text.present? || end_date_chip_text.present? || status_chips.any?
  end

  def start_date_chip_text
    return nil unless @projekt&.show_start_date_in_frontend? && @projekt&.total_duration_start.present?

    I18n.t("custom.projekts.page.sidebar.banner.start_date_chip",
      date: I18n.l(@projekt.total_duration_start, format: :long))
  end

  def end_date_chip_text
    return nil unless @projekt&.show_end_date_in_frontend? && @projekt&.total_duration_end.present?

    I18n.t("custom.projekts.page.sidebar.banner.end_date_chip",
      date: I18n.l(@projekt.total_duration_end, format: :long))
  end

  def status_chips
    return [] unless @projekt.present?

    if @projekt.expired?
      return [] unless @projekt.show_end_date_in_frontend?

      [{ icon: "check-circle",
         icon_style: "far",
         text: I18n.t("custom.projekts.page.sidebar.banner.projekt_completed_chip"),
         modifier: "-completed" }]
    elsif projekt_not_started?
      return [] unless @projekt.show_start_date_in_frontend?

      [{ icon: "clock",
         icon_style: "far",
         text: I18n.t("custom.projekts.page.sidebar.banner.projekt_starts_soon_chip"),
         modifier: "-upcoming" }]
    else
      running_phase_chips
    end
  end

  private

    # Completed/upcoming status is driven by the projekt's own duration, never
    # by its phases. `expired?` covers the past end date; this covers the
    # not-yet-started case (a future start date).
    def projekt_not_started?
      @projekt.total_duration_start.present? &&
        @projekt.total_duration_start > Time.zone.today
    end

    # While the projekt is within its duration we keep the per-phase chips,
    # each linking to its footer tab.
    def running_phase_chips
      @projekt.active_and_visible_projekt_phases.current.map do |phase|
        { phase: phase,
          index: footer_tab_index_for(phase),
          icon: "circle",
          icon_style: "fas",
          text: phase.title,
          modifier: "-running" }
      end
    end

    # Mirrors the iteration used by Pages::Projekts::SidebarPhasesComponent
    # (`projekt.projekt_phases.active.sorted` with the same skip rules) so the
    # data-index attribute on the banner chips lines up with the sidebar links
    # and is consumed identically by FooterPhasesComponentCustom JS.
    def footer_tab_index_for(target_phase)
      sidebar_phases = @projekt.projekt_phases.active.sorted.to_a
      raw_index = sidebar_phases.each_with_index.find do |phase, _idx|
        next false if phase.name == "budget_phase" && phase.budget.blank?

        phase.id == target_phase.id
      end&.last

      raw_index ? raw_index - 1 : 0
    end
end
