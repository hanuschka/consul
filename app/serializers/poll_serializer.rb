class PollSerializer < BaseSerializer
  attr_reader :poll

  def initialize(poll)
    @poll = poll
  end

  def serialize
    poll_data = poll.as_json(
      only: [
        :id,
        :starts_at,
        :ends_at,
        :geozone_restricted,
        :budget_id,
        :created_at,
        :updated_at
      ]
    )

    poll_data.merge!(
      name: poll.name,
      summary: poll.summary,
      description: poll.description
    )

    if poll.geozone_restricted? && poll.geozones.any?
      poll_data[:geozones] = poll.geozones.map do |geozone|
        {
          id: geozone.id,
          name: geozone.name
        }
      end
    end

    if poll.budget.present?
      poll_data[:budget] = {
        id: poll.budget.id,
        name: poll.budget.name
      }
    end

    if poll.questions.any?
      poll_data[:questions] = poll.questions.map do |question|
        {
          id: question.id,
          title: question.title
        }
      end
    end

    poll_data
  end

  def self.serialize_collection(polls)
    polls.map { |poll| new(poll).serialize }
  end
end

