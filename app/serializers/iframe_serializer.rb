class IframeSerializer < BaseSerializer
  SETTING_KEYS = {
    url: "option.general.iframe_url",
    width: "option.general.iframe_width",
    height: "option.general.iframe_height"
  }.freeze

  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def serialize
    setting_values = projekt_phase.settings
      .where(key: SETTING_KEYS.values)
      .pluck(:key, :value)
      .to_h
    iframe_data = {}

    SETTING_KEYS.each do |attribute, key|
      iframe_data[attribute] = setting_values[key] if setting_values.key?(key)
    end

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
