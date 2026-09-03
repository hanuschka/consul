# The one way a drafted contribution becomes public. Four flows reached this
# point separately -- the ordinary form, the AI flow, the similar-contributions
# check and the WhatsApp bot -- and each had its own idea of what publishing
# entails, so whether a contribution notified the projekt's followers, mailed
# its author a confirmation, or became findable by anyone else's similarity
# check depended on which door it came through.
#
# The caller still owns everything that belongs to the submission rather than to
# the publication: validation, moderation, and the phase's criteria evaluation.
class UserResources::PublishService < ApplicationService
  def initialize(resource)
    @resource = resource
  end

  def call
    resource.update!(draft: false)

    release
    record_for_similarity_checks
    notify_author

    resource
  end

  private

    attr_reader :resource

    # Proposal#publish stamps published_at and runs the projekt's follower
    # notifications. An investment has no such method, so it is stamped here and
    # given the notifier of its own.
    def release
      return resource.publish if !investment?

      resource.update!(published_at: Time.current)

      ::NotificationServices::NewBudgetInvestmentNotifier.call(resource.id)
    end

    # Without the embedding the contribution exists for readers but not for the
    # check, so nobody submitting the same idea later would ever be shown it.
    def record_for_similarity_checks
      ::SimilarContributions::RecordGroupJob.perform_later(resource)
      ::SimilarContributions::EmbedJob.perform_later(resource)
    end

    def notify_author
      if investment?
        ::Mailer.budget_investment_created(resource).deliver_later
      else
        ::Mailer.proposal_created(resource).deliver_later
      end
    end

    def investment?
      resource.is_a?(::Budget::Investment)
    end
end
