class MilestoneSerializer < BaseSerializer
  attr_reader :milestone

  def initialize(milestone)
    @milestone = milestone
  end

  def serialize
    milestone_data = milestone.as_json(
      only: [
        :id,
        :title,
        :description,
        :publication_date,
        :custom_date,
        :milestoneable_type,
        :milestoneable_id,
        :status_id,
        :created_at,
        :updated_at
      ]
    )

    if milestone.status.present?
      milestone_data[:status] = {
        id: milestone.status.id,
        name: milestone.status.name
      }
    end

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

    if milestone.respond_to?(:image) && milestone.image.present? && milestone.image.attached?
      milestone_data[:image_url] = milestone.image.url
    end

    milestone_data
  end

  def self.serialize_collection(milestones)
    milestones.map { |milestone| new(milestone).serialize }
  end
end
