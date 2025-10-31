class ProjektArgumentSerializer < BaseSerializer
  attr_reader :projekt_argument

  def initialize(projekt_argument)
    @projekt_argument = projekt_argument
  end

  def serialize
    argument_data = projekt_argument.as_json(
      only: [
        :id,
        :name,
        :position,
        :note,
        :pro,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

    if projekt_argument.projekt_phase.present?
      argument_data[:projekt_phase] = {
        id: projekt_argument.projekt_phase.id,
        title: projekt_argument.projekt_phase.phase_tab_name,
        type: projekt_argument.projekt_phase.type,
        projekt_id: projekt_argument.projekt_phase.projekt_id
      }

      if projekt_argument.projekt_phase.projekt.present?
        projekt = projekt_argument.projekt_phase.projekt
        argument_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    if projekt_argument.respond_to?(:image) && projekt_argument.image.present? && projekt_argument.image.attached?
      argument_data[:image_url] = projekt_argument.image.url
    end

    argument_data
  end

  def self.serialize_collection(arguments)
    arguments.map { |argument| new(argument).serialize }
  end
end

