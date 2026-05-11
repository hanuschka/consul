class Projekts::BannerComponent < ApplicationComponent
  def initialize(custom_page:, compact: false)
    @custom_page = custom_page
    @projekt = custom_page.projekt
    @compact = compact
  end

  def show_embedded_controlls?
    return false if @compact

    @show_embedded_controlls ||= show_admin_controls_for_projekt?(@projekt)
  end

  def banner_wrapper_class
    classes = ["custom-page--banner-wrapper"]
    classes << "-compact" if @compact
    classes.join(" ")
  end

  def show_meta_chips?
    return false if @compact
    return false unless @projekt.present?

    end_date_chip_text.present? || phase_status_chips.any?
  end

  def end_date_chip_text
    return nil unless @projekt&.total_duration_end.present?

    I18n.t("custom.projekts.page.sidebar.banner.end_date_chip",
      date: I18n.l(@projekt.total_duration_end, format: :long))
  end

  def phase_status_chips
    return [] unless @projekt.present?

    visible_phases = @projekt.active_and_visible_projekt_phases
    return [] if visible_phases.empty?

    current_phases = visible_phases.current
    if current_phases.any?
      current_phases.map do |phase|
        { phase: phase,
          index: footer_tab_index_for(phase),
          icon: "circle",
          icon_style: "fas",
          text: phase.title,
          modifier: "-running" }
      end
    elsif visible_phases.all?(&:expired?)
      [{ icon: "check-circle",
         icon_style: "far",
         text: I18n.t("custom.projekts.page.sidebar.banner.projekt_completed_chip"),
         modifier: "-completed" }]
    else
      [{ icon: "clock",
         icon_style: "far",
         text: I18n.t("custom.projekts.page.sidebar.banner.projekt_starts_soon_chip"),
         modifier: "-upcoming" }]
    end
  end

  private

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
