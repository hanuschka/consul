# Writes the admin's review-step edits onto the projekt the copy just produced.
#
# It runs after the copy rather than before it because the bundle is read
# verbatim by the copier: changing a serialized graph in flight is how a
# reference ends up pointing at a record that was never written.
class ProjektImports::ApplyBundleOverlayService < ApplicationService
  def initialize(projekt:, overlay:, id_map:, locale:)
    @projekt = projekt
    @overlay = overlay || {}
    @id_map = id_map
    @locale = locale.to_s
  end

  def call
    apply_projekt_attributes
    apply_phase_names

    ServiceResult.success(projekt: projekt)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ApplyBundleOverlayService] #{e.class}: #{e.message}")

    ServiceResult.failure(error: e.message, error_details: { "class" => e.class.name })
  end

  private

    attr_reader :projekt, :overlay, :id_map, :locale

    def apply_projekt_attributes
      attributes = {
        name: overlay["name"].presence,
        total_duration_start: parse_date(overlay["starts_at"]),
        total_duration_end: parse_date(overlay["ends_at"])
      }.compact

      return if attributes.empty?

      projekt.update!(attributes)

      return if attributes[:name].blank?

      projekt.page&.update!(title: attributes[:name])
    end

    # The tab name is a translated column, so it is written in the import's own
    # locale — the same one the review form read it in.
    def apply_phase_names
      Array(overlay["phase_names"]).each do |entry|
        name = entry["name"].to_s.strip
        next if name.blank?

        phase = copied_phase_for(entry["source_id"])
        next if phase.blank?

        I18n.with_locale(locale) { phase.update!(phase_tab_name: name) }
      end
    end

    def copied_phase_for(source_id)
      copy_id = id_map&.copy_id_for(ProjektPhase, source_id)
      return nil if copy_id.blank?

      projekt.projekt_phases.find_by(id: copy_id)
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
end
