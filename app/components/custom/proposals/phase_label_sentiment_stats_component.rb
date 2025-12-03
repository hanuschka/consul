class Proposals::PhaseLabelSentimentStatsComponent < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def labels_data
    @labels_data ||= calculate_labels_data
  end

  def sentiments_data
    @sentiments_data ||= calculate_sentiments_data
  end

  def labels_title
    @projekt_phase.projekt_labels_label_text
  end

  def sentiments_title
    @projekt_phase.sentiment_label_text
  end

  def render?
    labels_data[:labels].any? || sentiments_data[:labels].any?
  end

  private

  def calculate_labels_data
    labels = @projekt_phase.projekt_labels.includes(:translations)
    proposal_ids = @projekt_phase.proposals.select(:id)

    label_names = []
    label_counts = []

    labels.each do |label|
      count = ProjektLabeling.where(
        projekt_label_id: label.id,
        labelable_type: "Proposal",
        labelable_id: proposal_ids
      ).count

      label_names << label.name
      label_counts << count
    end

    { labels: label_names, values: label_counts }
  end

  def calculate_sentiments_data
    sentiments = @projekt_phase.sentiments.includes(:translations)
    proposal_ids = @projekt_phase.proposals.select(:id)

    sentiment_names = []
    sentiment_counts = []
    sentiment_colors = []

    sentiments.each do |sentiment|
      count = Proposal.where(id: proposal_ids, sentiment_id: sentiment.id).count

      sentiment_names << sentiment.name
      sentiment_counts << count
      sentiment_colors << sentiment.color
    end

    { labels: sentiment_names, values: sentiment_counts, colors: sentiment_colors }
  end
end

