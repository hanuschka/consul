class MilestoneSerializer < BaseSerializer
  TRANSLATED_ATTRIBUTES = %w[title description custom_date].freeze

  attr_reader :milestone

  def initialize(milestone, client: nil)
    @milestone = milestone
    @client = client
  end

  def serialize
    milestone_data = milestone.as_json(
      only: [
        :id,
        :publication_date,
        :milestoneable_type,
        :milestoneable_id,
        :status_id,
        :created_at,
        :updated_at
      ]
    )

    milestone_data.merge!(
      title: milestone.title,
      description: milestone.description,
      custom_date: milestone.custom_date,
      translations: serialize_translations(milestone, TRANSLATED_ATTRIBUTES),
      status: serialize_status,
      documents: DocumentSerializer.serialize_collection(milestone.documents)
    )

    if milestone.milestoneable.present?
      milestoneable = milestone.milestoneable
      milestone_data[:milestoneable] = {
        id: milestoneable.id,
        type: milestone.milestoneable_type
      }

      # If the milestoneable is a ProjektPhase, include projekt info
      if milestoneable.is_a?(ProjektPhase)
        milestone_data[:milestoneable][:title] = milestoneable.phase_tab_name
        milestone_data[:milestoneable][:projekt_id] = milestoneable.projekt_id

        if milestoneable.projekt.present?
          projekt = milestoneable.projekt
          milestone_data[:projekt] = {
            id: projekt.id,
            title: projekt.page&.title || projekt.name
          }
        end
      end
    end

    if milestone.image.present?
      serialized_image = ImageSerializer.new(milestone.image, include_variants: false).serialize
      milestone_data[:image] = serialized_image if serialized_image.present?
    end

    milestone_data
  end

  def self.serialize_collection(milestones, client: nil)
    milestones.map { |milestone| new(milestone, client: client).serialize }
  end

  private

    def serialize_status
      return if milestone.status.blank?

      {
        id: milestone.status.id,
        name: milestone.status.name,
        description: milestone.status.description
      }
    end
end
