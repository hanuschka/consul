class Whatsapp::PublishedResultsQuery < ApplicationQuery
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

  def initialize(projekt: nil, from: 0)
    @projekt = projekt
    @from = from
  end

  # Translations because every caller names the phase, and ProjektPhase#title
  # reads the translated phase_tab_name — one query per row otherwise.
  #
  # Paged after the filter for the same reason it is filtered in Ruby at all:
  # whether an evaluation is public is a per-record decision, so the rows before
  # the window are only knowable once they have been tested.
  def call
    ::Whatsapp::ListWindow.page(publicly_visible, from: @from)
  end

  # Bounded by CANDIDATE_LIMIT rather than by the portal, which is what the
  # constant is for: past sixty the count stops being exact and the citizen is
  # better served by naming a projekt than by paging.
  def total
    publicly_visible.size
  end

  # Answers the menus without the projekt pages the rows themselves need, and
  # stops at the first phase with a public evaluation.
  def exists?
    candidates.lazy.any? { |projekt_phase| publicly_visible?(projekt_phase) }
  end

  # Nil for a phase whose evaluation is not public, which is also how a caller
  # re-checks a row the citizen tapped long after it was sent.
  #
  # The tab list is derived once: asking evaluation_tab_publicly_visible? per
  # tab rebuilds it from the evaluation snapshot each time.
  def self.public_section_for(projekt_phase)
    return if !projekt_phase.evaluation_completed?

    public_tabs = projekt_phase.publicly_visible_evaluation_tabs

    SECTIONS_BY_TAB.find { |tab, _section| public_tabs.include?(tab) }&.last
  end

  private

    def publicly_visible
      @publicly_visible ||=
        candidates
          .includes(:translations, projekt: :page)
          .select { |projekt_phase| publicly_visible?(projekt_phase) }
    end

    def candidates
      scope = ProjektPhase
        .joins(:projekt_phase_evaluation)
        .of_publicly_visible_projekt
        .includes(:projekt_phase_evaluation, :projekt_phase_evaluation_visibility)
        .order(Arel.sql("projekt_phases.end_date DESC NULLS LAST"))
        .limit(CANDIDATE_LIMIT)

      return scope if @projekt.blank?

      scope.where(projekt_id: @projekt.id)
    end

    # Deliberately only the public predicate. The footer helper has a second
    # branch that shows unpublished tabs to admins, and the bot must never take
    # it: on WhatsApp there is no session to tell an admin from anyone else.
    def publicly_visible?(projekt_phase)
      self.class.public_section_for(projekt_phase).present?
    end
end
