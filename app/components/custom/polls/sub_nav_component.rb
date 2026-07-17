# frozen_string_literal: true

class Polls::SubNavComponent < ApplicationComponent
  attr_reader :poll
  delegate :can?, :results_menu?, :stats_menu?, :info_menu?, :evaluation_menu?, :report_menu?,
           :ai_analysis_menu?, :poll_ai_analysis_visible?, to: :helpers

  def initialize(poll:)
    @poll = poll
  end

  def render?
    can?(:stats, poll) || can?(:results, poll) || can?(:report, poll) ||
      report_visible? || poll_ai_analysis_visible?(poll)
  end

  private

  def report_visible?
    poll.report_visible_for_citizens? || can?(:edit, poll.projekt) || helpers.current_user&.administrator?
  end

  def stats_hidden_from_public?
    !poll.projekt_phase.evaluation_tab_publicly_visible?("poll_stats")
  end

  def results_hidden_from_public?
    !poll.projekt_phase.evaluation_tab_publicly_visible?("stats")
  end
end
