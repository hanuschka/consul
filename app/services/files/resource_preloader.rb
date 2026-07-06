module Files::ResourcePreloader
  module_function

  def call(records)
    records = records.compact
    nested_page = { page: :translations }
    phase_projekt = { projekt_phase: { projekt: nested_page } }

    preload(records.select { |r| r.is_a?(Projekt) }, nested_page)
    preload(records.select { |r| r.is_a?(ProjektPhase) }, [:translations, { projekt: nested_page }])
    preload(records.select { |r| r.is_a?(ProjektArgument) }, projekt_phase: { projekt: nested_page })
    preload(records.select { |r| r.is_a?(SiteCustomization::Page) }, :translations)
    preload(records.select { |r| r.is_a?(Proposal) }, [:translations, phase_projekt])
    preload(records.select { |r| r.is_a?(Debate) }, [:translations, phase_projekt])
    preload(records.select { |r| r.is_a?(Poll) }, [:translations, phase_projekt])
    preload(records.select { |r| r.is_a?(Budget::Investment) }, budget: phase_projekt)
    preload(records.select { |r| r.is_a?(DeficiencyReport) }, :translations)
    preload(records.select { |r| r.is_a?(Idea) }, :translations)
    preload(records.select { |r| r.is_a?(Budget) }, :translations)
    preload(records.select { |r| r.is_a?(Budget::Phase) }, :translations)
    preload(records.select { |r| r.is_a?(Legislation::Process) }, :translations)

    milestones = records.select { |r| r.is_a?(Milestone) }
    preload(milestones, [:translations, :milestoneable])

    cards = records.select { |r| r.is_a?(Widget::Card) }
    preload(cards, [:translations, :cardable])

    nested = milestones.map(&:milestoneable) + cards.map(&:cardable)

    if nested.compact.any?
      call(nested)
    end
  end

  def preload(records, associations)
    return if records.empty?

    ActiveRecord::Associations::Preloader.new.preload(records, associations)
  end
end
