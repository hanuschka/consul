class LegislationProcessSerializer < BaseSerializer
  attr_reader :legislation_process

  def initialize(legislation_process)
    @legislation_process = legislation_process
  end

  def serialize
    process_data = legislation_process.as_json(
      only: [
        :id,
        :start_date,
        :end_date,
        :debate_start_date,
        :debate_end_date,
        :draft_publication_date,
        :allegations_start_date,
        :allegations_end_date,
        :result_publication_date,
        :debate_phase_enabled,
        :allegations_phase_enabled,
        :draft_publication_enabled,
        :result_publication_enabled,
        :published,
        :created_at,
        :updated_at
      ]
    )

    process_data.merge!(
      title: legislation_process.title,
      summary: legislation_process.summary,
      description: legislation_process.description
    )

    if legislation_process.respond_to?(:projekt_phase) && legislation_process.projekt_phase.present?
      process_data[:projekt_phase] = {
        id: legislation_process.projekt_phase.id,
        title: legislation_process.projekt_phase.phase_tab_name,
        type: legislation_process.projekt_phase.type,
        projekt_id: legislation_process.projekt_phase.projekt_id
      }

      if legislation_process.projekt_phase.projekt.present?
        projekt = legislation_process.projekt_phase.projekt
        process_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    if legislation_process.respond_to?(:proposals) && legislation_process.proposals.any?
      process_data[:proposals_count] = legislation_process.proposals.count
    end

    process_data
  end

  def self.serialize_collection(processes)
    processes.map { |process| new(process).serialize }
  end
end

