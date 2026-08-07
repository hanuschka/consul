class WhatsappPublishedResultsQuery < ApplicationQuery
  MAX_CHOICES = 10

  # Enough rows to fill the list several times over after the Ruby filter, but
  # bounded: whether an evaluation is public is a per-record decision no SQL
  # predicate can make.
  CANDIDATE_LIMIT = 60

  # Which footer tab carries the result, and the projekt page's section param
  # that opens it. Ordered by what a citizen most likely means by "results", so
  # a phase with several public tabs is linked to the richest one.
  SECTIONS_BY_TAB = {
    "stats" => "evaluation",
    "poll_stats" => "poll_stats",
    "ai" => "ai_evaluation"
  }.freeze

  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    candidates.select { |projekt_phase| publicly_visible?(projekt_phase) }.first(MAX_CHOICES)
  end

  # Nil for a phase whose evaluation is not public, which is also how a caller
  # re-checks a row the citizen tapped long after it was sent.
  def self.public_section_for(projekt_phase)
    return if !projekt_phase.evaluation_completed?

    SECTIONS_BY_TAB
      .find { |tab, _section| projekt_phase.evaluation_tab_publicly_visible?(tab) }
      &.last
  end

  private

    def candidates
      scope = ProjektPhase
        .joins(:projekt_phase_evaluation)
        .joins(projekt: :page)
        .where(site_customization_pages: { status: "published" })
        .merge(Projekt.activated)
        .includes(:projekt_phase_evaluation, :projekt_phase_evaluation_visibility, projekt: :page)
        .order(Arel.sql("projekt_phases.end_date DESC NULLS LAST"))
        .limit(CANDIDATE_LIMIT)

      scope = scope.where(projekt_id: @projekt.id) if @projekt.present?

      scope.to_a
    end

    # Deliberately only the public predicate. The footer helper has a second
    # branch that shows unpublished tabs to admins, and the bot must never take
    # it: on WhatsApp there is no session to tell an admin from anyone else.
    def publicly_visible?(projekt_phase)
      self.class.public_section_for(projekt_phase).present?
    end
end
