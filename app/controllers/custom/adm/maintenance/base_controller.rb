class Adm::Maintenance::BaseController < Adm::BaseController
  private

    def current_adm_section_namespace
      "Adm"
    end

    def preload_resource_associations(records)
      records = records.compact
      nested_page = { page: :translations }

      preload_records(records.select { |r| r.is_a?(Projekt) }, nested_page)
      preload_records(records.select { |r| r.is_a?(ProjektPhase) }, [:translations, { projekt: nested_page }])
      preload_records(
        records.select { |r| r.is_a?(ProjektArgument) },
        projekt_phase: { projekt: nested_page }
      )
      preload_records(records.select { |r| r.is_a?(SiteCustomization::Page) }, :translations)
      preload_records(records.select { |r| r.is_a?(Proposal) }, :translations)
      preload_records(records.select { |r| r.is_a?(Debate) }, :translations)
      preload_records(records.select { |r| r.is_a?(Poll) }, :translations)
      preload_records(records.select { |r| r.is_a?(DeficiencyReport) }, :translations)

      milestones = records.select { |r| r.is_a?(Milestone) }
      preload_records(milestones, [:translations, :milestoneable])

      cards = records.select { |r| r.is_a?(Widget::Card) }
      preload_records(cards, [:translations, :cardable])

      nested = milestones.map(&:milestoneable) + cards.map(&:cardable)

      if nested.compact.any?
        preload_resource_associations(nested)
      end
    end

    def preload_records(records, associations)
      return if records.empty?

      ActiveRecord::Associations::Preloader.new.preload(records, associations)
    end
end
