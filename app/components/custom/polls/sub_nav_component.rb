# frozen_string_literal: true

class Polls::SubNavComponent < ApplicationComponent
  attr_reader :poll
  delegate :can?, :results_menu?, :stats_menu?, :info_menu?, :evaluation_menu?, :report_menu?, to: :helpers

  def initialize(poll:)
    @poll = poll
  end

  def render?
    can?(:stats, poll) || can?(:results, poll) || can?(:report, poll) || report_visible?
  end

  private

  def report_visible?
    poll.report_visible_for_citizens? || can?(:edit, poll.projekt) || helpers.current_user&.administrator?
  end
end
