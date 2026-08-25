class Projekts::Copying::Serializing::PhaseResourceSerializer < ApplicationService
  # Resources keyed only by projekt_phase_id, queried by column rather than
  # through the phase associations because each phase subclass names them
  # differently. masterportal_collection_id is dropped: masterportal data is
  # never copied, so keeping it would point the copy at the source's collection.
  PLAIN_RESOURCE_MODELS = Projekts::Copying::PhaseResourceCopier::PLAIN_RESOURCE_MODELS

  EXCLUDED_RESOURCE_COLUMNS = %w[masterportal_collection_id].freeze

  def initialize(source_phase:)
    @source_phase = source_phase
  end

  def call
    {
      "milestones" => attachable_nodes(source_phase.milestones),
      "progress_bars" => plain_nodes(source_phase.progress_bars),
      "plain" => plain_resource_nodes,
      "point_of_interest_categories" => point_of_interest_category_nodes,
      "polls" => Projekts::Copying::Serializing::PollSerializer.call(source_phase: source_phase),
      "budgets" => Projekts::Copying::Serializing::BudgetSerializer.call(
        source_phase: source_phase
      ),
      "formular" => Projekts::Copying::Serializing::FormularSerializer.call(
        source_phase: source_phase
      )
    }
  end

  private

    attr_reader :source_phase

    def plain_resource_nodes
      PLAIN_RESOURCE_MODELS.each_with_object({}) do |model, result|
        records = model.where(projekt_phase_id: source_phase.id).order(:id)
        next if records.empty?

        result[model.name] = attachable_nodes(records)
      end
    end

    def point_of_interest_category_nodes
      categories = ProjektPointOfInterestCategory
        .where(projekt_phase_id: source_phase.id)
        .order(:id)

      categories.map do |category|
        Projekts::Copying::Serializing::RecordSerializer.call(
          category, except: EXCLUDED_RESOURCE_COLUMNS, attachments: %i[icon_image]
        )
      end
    end

    def attachable_nodes(records)
      records.map do |record|
        Projekts::Copying::Serializing::RecordSerializer
          .call(record, except: EXCLUDED_RESOURCE_COLUMNS)
          .merge(Projekts::Copying::Serializing::AttachableSerializer.call(record: record))
      end
    end

    def plain_nodes(records)
      records.map do |record|
        Projekts::Copying::Serializing::RecordSerializer.call(
          record, except: EXCLUDED_RESOURCE_COLUMNS
        )
      end
    end
end
