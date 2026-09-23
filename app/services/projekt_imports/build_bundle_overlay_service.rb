# Reads out of a fetched Consul bundle the handful of things the admin is
# allowed to change before the copy runs.
#
# The bundle itself is never edited: it is a serialized graph the copier reads
# verbatim, and the chat's edit tools only understand the ai_result shape. So
# the review step edits this small overlay instead, and ApplyBundleOverlay
# writes it onto the projekt once the copy has produced one.
class ProjektImports::BuildBundleOverlayService < ApplicationService
  def initialize(bundle:, locale:)
    @bundle = bundle
    @locale = locale.to_s
  end

  def call
    projekt_attributes = bundle.dig("projekt", "attributes") || {}

    ServiceResult.success(
      overlay: {
        "name" => projekt_attributes["name"].to_s,
        "starts_at" => projekt_attributes["total_duration_start"],
        "ends_at" => projekt_attributes["total_duration_end"],
        "phase_names" => phase_names
      }
    )
  end

  private

    attr_reader :bundle, :locale

    # Keyed by the source's row id, which is the only handle the bundle and the
    # copier's id map agree on. A phase whose tab name is untranslated in the
    # import locale falls back to whatever locale the source did have, so the
    # admin sees a name to edit rather than an empty box. Type and dates are
    # read-only context for the review form; only the name is written back.
    def phase_names
      Array(bundle["phases"]).map do |phase|
        attributes = phase["attributes"] || {}

        {
          "source_id" => phase["source_id"],
          "name" => phase_name_for(phase),
          "type" => attributes["type"],
          "starts_at" => attributes["start_date"],
          "ends_at" => attributes["end_date"]
        }
      end
    end

    def phase_name_for(phase)
      translations = phase["translations"] || {}
      preferred = translations[locale] || translations.values.first || {}

      preferred["phase_tab_name"].to_s
    end
end
