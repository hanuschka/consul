module RecipientGroups
  module FilterResolvers
    class NewsletterSubscribers < Base
      def emails
        base = User.actual.where(newsletter: true).pluck(:email)
        base += UnregisteredNewsletterSubscriber.confirmed.pluck(:email) if params[:include_unregistered]
        base.compact.uniq
      end
    end
  end
end
