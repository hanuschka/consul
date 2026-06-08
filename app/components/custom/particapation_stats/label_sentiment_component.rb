class ParticapationStats::LabelSentimentComponent < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def labels_data
    query.labels_data
  end

  def sentiments_data
    query.sentiments_data
  end

  def labels_title
    query.labels_title
  end

  def sentiments_title
    query.sentiments_title
  end

  def render?
    labels_data[:labels].any? || sentiments_data[:labels].any?
  end

  private

    def query
      @query ||= ProjektPhaseStats::LabelSentimentQuery.new(@projekt_phase)
    end
end
