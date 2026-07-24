class Adm::MasterportalCollectionCardComponent < ApplicationComponent
  DEFAULT_FEATURE_COLOR = "#2e7d32".freeze

  with_collection_parameter :collection

  attr_reader :collection, :projekt_phase, :diff, :diff_error

  def initialize(collection:, projekt_phase:, diff: nil, diff_error: nil)
    @collection = collection
    @projekt_phase = projekt_phase
    @diff = diff
    @diff_error = diff_error
  end

  def update_url
    helpers.update_masterportal_collection_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def update_color_url
    helpers.update_masterportal_collection_color_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def feature_color
    collection.feature_color.presence || DEFAULT_FEATURE_COLOR
  end

  def delete_url
    helpers.destroy_masterportal_collection_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def status_url
    helpers.masterportal_collection_status_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def diff_url
    helpers.masterportal_collection_diff_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def clean_url
    helpers.clean_masterportal_collection_stale_pins_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def card_url
    helpers.masterportal_collection_card_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def icon_src
    collection.encoded_icon_url
  end

  def diff_badge_hidden?
    diff.blank? && diff_error.blank?
  end

  def diff_badge_state
    return "error" if diff_error.present?
    return "current" if diff.blank?

    diff_has_changes? ? "changes" : "current"
  end

  def diff_badge_icon
    return "error" if diff_error.present?

    diff_has_changes? ? "difference" : "check_circle"
  end

  def diff_badge_text
    return diff_error if diff_error.present?
    return if diff.blank?

    parts = diff_badge_parts
    parts.any? ? parts.join(" · ") : t(".diff.current_label")
  end

  private

    def diff_has_changes?
      return false if diff.blank?

      diff[:new_count].to_i.positive? || diff[:stale_count].to_i.positive?
    end

    def diff_badge_parts
      parts = []

      if diff[:new_count].to_i.positive?
        parts << "+#{diff[:new_count]} #{t(".diff.new_label")}"
      end

      if diff[:stale_count].to_i.positive?
        parts << "−#{diff[:stale_count]} #{t(".diff.stale_label")}"
      end

      parts
    end
end
