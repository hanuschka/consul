class ProjektLabelSerializer < BaseSerializer
  def initialize(projekt_label)
    @projekt_label = projekt_label
  end

  def serialize
    {
      id: projekt_label.id,
      projekt_phase_id: projekt_label.projekt_phase_id,
      name: projekt_label.name,
      color: projekt_label.color,
      icon: projekt_label.icon,
      masterportal_collection_id: projekt_label.masterportal_collection_id,
      translations: serialize_translations(projekt_label),
      created_at: projekt_label.created_at,
      updated_at: projekt_label.updated_at
    }
  end

  private

    attr_reader :projekt_label
end
