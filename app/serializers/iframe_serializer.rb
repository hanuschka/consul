class IframeSerializer < BaseSerializer
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def serialize
    iframe_data = {}

    url_setting = projekt_phase.settings.find_by(key: "option.iframe.url")
    iframe_data[:url] = url_setting&.value if url_setting

    width_setting = projekt_phase.settings.find_by(key: "option.iframe.width")
    iframe_data[:width] = width_setting&.value if width_setting

    height_setting = projekt_phase.settings.find_by(key: "option.iframe.height")
    iframe_data[:height] = height_setting&.value if height_setting

    projekt_phase_data = {
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
      projekt_phase_data[:projekt] = {
        id: projekt.id,
        title: projekt.page&.title || projekt.name
      }
    end

    iframe_data[:projekt_phase] = projekt_phase_data

    iframe_data
  end

  def self.serialize_collection(projekt_phases)
    projekt_phases.map { |phase| new(phase).serialize }
  end
end
