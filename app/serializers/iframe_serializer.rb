class IframeSerializer < BaseSerializer
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def serialize
    iframe_data = {
      id: projekt_phase.id,
      type: projekt_phase.type,
      title: projekt_phase.phase_tab_name,
      projekt_id: projekt_phase.projekt_id,
      active: projekt_phase.active?,
      created_at: projekt_phase.created_at,
      updated_at: projekt_phase.updated_at
    }

    if projekt_phase.projekt.present?
      projekt = projekt_phase.projekt
      iframe_data[:projekt] = {
        id: projekt.id,
        title: projekt.page&.title || projekt.name
      }
    end

    # Include iframe-specific settings
    iframe_url_setting = projekt_phase.settings.find_by(key: "option.iframe.url")
    iframe_data[:iframe_url] = iframe_url_setting&.value if iframe_url_setting

    iframe_height_setting = projekt_phase.settings.find_by(key: "option.iframe.height")
    iframe_data[:iframe_height] = iframe_height_setting&.value if iframe_height_setting

    iframe_data
  end

  def self.serialize_collection(projekt_phases)
    projekt_phases.map { |phase| new(phase).serialize }
  end
end
