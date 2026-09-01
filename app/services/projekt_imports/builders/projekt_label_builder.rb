class ProjektImports::Builders::ProjektLabelBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |label|
      name = label["name"].to_s.strip
      next nil if name.blank?

      phase.projekt_labels.create!(name: name, icon: known_icon(label["icon"]))
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "projekt_label(#{name}): #{e.message}"
    end
  end

  private

  # ProjektLabel has no validations, so an invented icon name would persist and
  # render as an empty glyph. Anything outside the picker list is dropped.
  def known_icon(icon)
    normalized = icon.to_s.strip.delete_prefix("fa-")
    return nil if normalized.blank?
    return nil if available_icons.exclude?(normalized)

    normalized
  end

  def available_icons
    @available_icons ||= Iconable::AVAILABLE_ICONS.flatten.to_set
  end
end
