class Projekts::Copying::PhaseResourceCopier < ApplicationService
  # Resources keyed only by projekt_phase_id and copied the same way. Queried by
  # column rather than through the phase associations, because each phase
  # subclass names them differently.
  PLAIN_RESOURCE_MODELS = [
    ProjektEvent,
    ProjektArgument,
    ProjektNotification,
    ProjektLivestream,
    Sentiment,
    ProjektLabel
  ].freeze

  def initialize(source_phase:, copy_phase:, record_copier:)
    @source_phase = source_phase
    @copy_phase = copy_phase
    @record_copier = record_copier
    @blob_copier = record_copier.blob_copier
  end

  def call
    copy_milestones
    copy_progress_bars
    copy_plain_resources
    copy_point_of_interest_categories

    Projekts::Copying::PollCopier.call(
      source_phase: source_phase, copy_phase: copy_phase,
      record_copier: record_copier
    )
    Projekts::Copying::BudgetCopier.call(
      source_phase: source_phase, copy_phase: copy_phase,
      record_copier: record_copier
    )
    Projekts::Copying::FormularCopier.call(
      source_phase: source_phase, copy_phase: copy_phase,
      record_copier: record_copier
    )
  end

  private

    attr_reader :source_phase, :copy_phase, :record_copier, :blob_copier

    def copy_milestones
      source_phase.milestones.each do |milestone|
        copy = record_copier.copy_record(milestone, attributes: { milestoneable: copy_phase })
        copy_attachables(milestone, copy)
      end
    end

    def copy_progress_bars
      record_copier.copy_all(
        source_phase.progress_bars,
        attributes: { progressable: copy_phase }
      )
    end

    def copy_plain_resources
      PLAIN_RESOURCE_MODELS.each do |model|
        model.where(projekt_phase_id: source_phase.id).find_each do |resource|
          copy = record_copier.copy_record(resource, attributes: phase_attributes(model))
          copy_attachables(resource, copy)
        end
      end
    end

    def copy_point_of_interest_categories
      categories = ProjektPointOfInterestCategory.where(projekt_phase_id: source_phase.id)

      categories.find_each do |category|
        copy = record_copier.build(
          category,
          attributes: phase_attributes(ProjektPointOfInterestCategory)
        )
        blob_copier.copy_one(category.icon_image, copy.icon_image)
        record_copier.persist(category, copy)
      end
    end

    # Several of these tables still carry a pre-phase projekt_id alongside
    # projekt_phase_id; it has to follow the copy too. masterportal_collection_id
    # is cleared instead: masterportal data is never copied, so keeping it would
    # leave the copy pointing at the source's collection.
    def phase_attributes(model)
      attributes = { projekt_phase_id: copy_phase.id }
      columns = model.column_names

      if columns.include?("projekt_id")
        attributes[:projekt_id] = copy_phase.projekt_id
      end

      if columns.include?("masterportal_collection_id")
        attributes[:masterportal_collection_id] = nil
      end

      attributes
    end

    def copy_attachables(source_record, copy_record)
      record_copier.copy_images(source_record, copy_record)
      record_copier.copy_documents(source_record, copy_record)
    end
end
