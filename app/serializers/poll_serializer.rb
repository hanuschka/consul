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

    if poll.projekt_phase.present?
      poll_data[:projekt_phase] = {
        id: poll.projekt_phase.id,
        title: poll.projekt_phase.phase_tab_name,
        type: poll.projekt_phase.type,
        projekt_id: poll.projekt_phase.projekt_id
      }

      if poll.projekt_phase.projekt.present?
        projekt = poll.projekt_phase.projekt
        poll_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

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
        Poll::QuestionSerializer.new(question).serialize
      end
    end

    poll_data
  end

  def self.serialize_collection(polls)
    polls.map { |poll| new(poll).serialize }
  end
end

