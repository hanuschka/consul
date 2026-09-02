class Projekts::Copying::PhaseResourceCopier < ApplicationService
  # Resources keyed only by projekt_phase_id and copied the same way. Indexed by
  # name because that is how the bundle keys them -- and a bundle can therefore
  # only ever name a model this list already contains.
  PLAIN_RESOURCE_MODELS = [
    ProjektEvent,
    ProjektArgument,
    ProjektNotification,
    ProjektLivestream,
    Sentiment,
    ProjektLabel
  ].freeze

  MODELS_BY_NAME = PLAIN_RESOURCE_MODELS.index_by(&:name).freeze

  def initialize(node:, copy_phase:, record_copier:)
    @node = node
    @copy_phase = copy_phase
    @record_copier = record_copier
  end

  def call
    return if node.blank?

    copy_milestones
    copy_progress_bars
    copy_plain_resources
    copy_point_of_interest_categories

    Projekts::Copying::PollCopier.call(
      nodes: node["polls"], copy_phase: copy_phase,
      record_copier: record_copier
    )
    Projekts::Copying::BudgetCopier.call(
      nodes: node["budgets"], copy_phase: copy_phase,
      record_copier: record_copier
    )
    Projekts::Copying::FormularCopier.call(
      node: node["formular"], copy_phase: copy_phase,
      record_copier: record_copier
    )
  end

  private

    attr_reader :node, :copy_phase, :record_copier

    def copy_milestones
      Array(node["milestones"]).each do |milestone_node|
        copy = record_copier.copy_record(
          milestone_node, attributes: { milestoneable: copy_phase }
        )
        record_copier.copy_attachments(milestone_node, copy)
      end
    end

    def copy_progress_bars
      record_copier.copy_all(
        node["progress_bars"],
        attributes: { progressable: copy_phase }
      )
    end

    def copy_plain_resources
      Hash(node["plain"]).each do |model_name, resource_nodes|
        model = MODELS_BY_NAME[model_name]
        next if model.blank?

        Array(resource_nodes).each do |resource_node|
          copy = record_copier.copy_record(
            resource_node, attributes: phase_attributes(model)
          )
          record_copier.copy_attachments(resource_node, copy)
        end
      end
    end

    def copy_point_of_interest_categories
      Array(node["point_of_interest_categories"]).each do |category_node|
        copy = record_copier.build(
          category_node,
          attributes: phase_attributes(ProjektPointOfInterestCategory)
        )
        record_copier.copy_attachment(category_node, :icon_image, copy.icon_image)
        record_copier.persist(category_node, copy)
      end
    end

    # Several of these tables still carry a pre-phase projekt_id alongside
    # projekt_phase_id; it has to follow the copy too.
    def phase_attributes(model)
      attributes = { projekt_phase_id: copy_phase.id }

      if model.column_names.include?("projekt_id")
        attributes[:projekt_id] = copy_phase.projekt_id
      end

      attributes
    end
end
