class MilestoneStatusSerializer < BaseSerializer
  attr_reader :milestone_status

  def initialize(milestone_status)
    @milestone_status = milestone_status
  end

  def serialize
    status_data = milestone_status.as_json(
      only: [
        :id,
        :name,
        :created_at,
        :updated_at
      ]
    )

    status_data[:milestones_count] = milestone_status.milestones.count if milestone_status.respond_to?(:milestones)

    status_data
  end

  def self.serialize_collection(statuses)
    statuses.map { |status| new(status).serialize }
  end
end
