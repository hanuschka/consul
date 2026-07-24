ActsAsVotable::Vote.class_eval do
  include Graphqlable

  before_create :set_conditional_flag

  belongs_to :signature
  belongs_to :budget_investment, foreign_key: "votable_id", class_name: "Budget::Investment"

  scope :public_for_api, -> do
    where(conditional: false)
      .where(votable: [Debate.public_for_api, Proposal.public_for_api, Comment.public_for_api])
  end

  def self.for_deficiency_reports(deficiency_reports)
    where(votable_type: "DeficiencyReport", votable_id: deficiency_reports)
  end

  def value
    vote_flag
  end

  private

    def set_conditional_flag
      self.conditional = votable.respond_to?(:conditional_vote_for?) &&
                         votable.conditional_vote_for?(voter)
    end
end

# Conditional votes are persisted but excluded from every count until the
# voter is verified (see ConditionallyVotable and User#verify!). Method
# bodies copied from acts_as_votable 0.14.0 with the conditional filter added;
# count_votes_score and weighted_average derive from these and need no override.
ActsAsVotable::Cacheable.module_eval do
  def count_votes_total(skip_cache = false, vote_scope = nil)
    from_cache(skip_cache, :cached_votes_total, vote_scope) do
      find_votes_for(scope_or_empty_hash(vote_scope)).where(conditional: false).count
    end
  end

  def count_votes_up(skip_cache = false, vote_scope = nil)
    from_cache(skip_cache, :cached_votes_up, vote_scope) do
      get_up_votes(vote_scope: vote_scope).where(conditional: false).count
    end
  end

  def count_votes_down(skip_cache = false, vote_scope = nil)
    from_cache(skip_cache, :cached_votes_down, vote_scope) do
      get_down_votes(vote_scope: vote_scope).where(conditional: false).count
    end
  end

  def weighted_total(skip_cache = false, vote_scope = nil)
    from_cache(skip_cache, :cached_weighted_total, vote_scope) do
      find_votes_for(scope_or_empty_hash(vote_scope)).where(conditional: false).sum(:vote_weight)
    end
  end

  def weighted_score(skip_cache = false, vote_scope = nil)
    from_cache(skip_cache, :cached_weighted_score, vote_scope) do
      ups = get_up_votes(vote_scope: vote_scope).where(conditional: false).sum(:vote_weight)
      downs = get_down_votes(vote_scope: vote_scope).where(conditional: false).sum(:vote_weight)
      ups - downs
    end
  end
end
