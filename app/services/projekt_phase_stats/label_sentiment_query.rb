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
    labels = @projekt_phase.projekt_labels.includes(:translations).to_a
    resource_ids = resources.select(:id)

    counts_by_label_id = ProjektLabeling.where(
      labelable_type: labelable_type,
      labelable_id: resource_ids
    ).group(:projekt_label_id).count

    {
      labels: labels.map(&:name),
      values: labels.map { |label| counts_by_label_id[label.id] || 0 }
    }
  end

  def sentiments_data
    sentiments = @projekt_phase.sentiments.includes(:translations).to_a
    resource_ids = resources.select(:id)

    counts_by_sentiment_id =
      resource_class.where(id: resource_ids).group(:sentiment_id).count

    {
      labels: sentiments.map(&:name),
      values: sentiments.map { |sentiment| counts_by_sentiment_id[sentiment.id] || 0 },
      colors: sentiments.map(&:color)
    }
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
