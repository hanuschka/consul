class ProjektPhaseStats::LabelSentimentQuery < ApplicationService
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    {
      labels: labels_data,
      sentiments: sentiments_data,
      labels_title: labels_title,
      sentiments_title: sentiments_title
    }
  end

  def labels_data
    labels = @projekt_phase.projekt_labels.includes(:translations)
    resource_ids = resources.select(:id)

    label_names = []
    label_counts = []

    labels.each do |label|
      count = ProjektLabeling.where(
        projekt_label_id: label.id,
        labelable_type: labelable_type,
        labelable_id: resource_ids
      ).count

      label_names << label.name
      label_counts << count
    end

    { labels: label_names, values: label_counts }
  end

  def sentiments_data
    sentiments = @projekt_phase.sentiments.includes(:translations)
    resource_ids = resources.select(:id)

    sentiment_names = []
    sentiment_counts = []
    sentiment_colors = []

    sentiments.each do |sentiment|
      count = resource_class.where(id: resource_ids, sentiment_id: sentiment.id).count

      sentiment_names << sentiment.name
      sentiment_counts << count
      sentiment_colors << sentiment.color
    end

    { labels: sentiment_names, values: sentiment_counts, colors: sentiment_colors }
  end

  def labels_title
    @projekt_phase.projekt_labels_label_text
  end

  def sentiments_title
    @projekt_phase.sentiment_label_text
  end

  private

    def resources
      @resources ||=
        case @projekt_phase
        when ProjektPhase::ProposalPhase
          @projekt_phase.proposals
        when ProjektPhase::BudgetPhase
          @projekt_phase.budget&.investments || Budget::Investment.none
        else
          Proposal.none
        end
    end

    def resource_class
      case @projekt_phase
      when ProjektPhase::ProposalPhase
        Proposal
      when ProjektPhase::BudgetPhase
        Budget::Investment
      else
        Proposal
      end
    end

    def labelable_type
      case @projekt_phase
      when ProjektPhase::ProposalPhase
        "Proposal"
      when ProjektPhase::BudgetPhase
        "Budget::Investment"
      else
        "Proposal"
      end
    end
end
