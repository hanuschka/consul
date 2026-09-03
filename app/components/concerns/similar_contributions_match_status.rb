# Where a match stands is read on two surfaces that compose it differently --
# the admin list puts it in its meta line, the badge popup gives it a line of
# its own -- so the label is built once here and scoped absolutely: a relative
# key would resolve against whichever component included the module.
module SimilarContributionsMatchStatus
  extend ActiveSupport::Concern

  STATUS_SCOPE = "components.similar_contributions.match_status".freeze

  def processing_status_for(match_resource)
    if match_resource.is_a?(::Budget::Investment)
      investment_status(match_resource)
    else
      proposal_status(match_resource)
    end
  end

  private

    def investment_status(investment)
      return status_label(:unfeasible) if investment.unfeasible?
      return status_label(:answered) if investment.valuation_finished?

      status_label(:open)
    end

    def proposal_status(proposal)
      return status_label(:retired) if proposal.retired?
      return status_label(:answered) if proposal.official_answer.present?

      status_label(:open)
    end

    def status_label(key)
      t("#{STATUS_SCOPE}.#{key}")
    end
end
