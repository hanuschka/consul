module Adm::Projekts::ImportReviewsHelper
  # The phase type is the stable, recognisable thing about a row; the editable
  # name sits in the input below it. Overlays built before the type was
  # recorded fall back to the row's position.
  def import_review_phase_label(phase, position)
    return t("adm.projekts.imports.reviews.show.phase_position", position: position) if phase["type"].blank?

    ProjektPhase.type_label_for(phase["type"])
  end

  # Overlays recorded before the dates were carried say nothing rather than
  # claiming the source phase has none.
  def import_review_phase_hint(phase)
    return nil if !phase.key?("starts_at")

    starts_on = import_review_date(phase["starts_at"])
    ends_on = import_review_date(phase["ends_at"])

    return t("adm.projekts.imports.reviews.show.phase_without_dates") if starts_on.nil? && ends_on.nil?

    import_summary_period(starts_on, ends_on)
  end

  private

    def import_review_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
end
