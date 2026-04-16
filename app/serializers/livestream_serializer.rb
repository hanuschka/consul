class LivestreamSerializer < BaseSerializer
  attr_reader :projekt_livestream

  def initialize(projekt_livestream)
    @projekt_livestream = projekt_livestream
  end

  def serialize
    livestream_data = projekt_livestream.as_json(
      only: [
        :id,
        :url,
        :title,
        :description,
        :starts_at,
        :video_platform,
        :external_id,
        :preview_image_url,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

    if projekt_livestream.projekt_phase.present?
      livestream_data[:projekt_phase] = {
        id: projekt_livestream.projekt_phase.id,
        title: projekt_livestream.projekt_phase.phase_tab_name,
        type: projekt_livestream.projekt_phase.type,
        projekt_id: projekt_livestream.projekt_phase.projekt_id
      }

      if projekt_livestream.projekt_phase.projekt.present?
        projekt = projekt_livestream.projekt_phase.projekt
        livestream_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    if projekt_livestream.projekt_questions.any?
      livestream_data[:questions] = QuestionSerializer.serialize_collection(
        projekt_livestream.projekt_questions
      )
    end

    livestream_data
  end

  def self.serialize_collection(livestreams)
    livestreams.map { |livestream| new(livestream).serialize }
  end
end

