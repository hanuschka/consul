module Adm::HidesContributions
  extend ActiveSupport::Concern

  private

    def hide_and_notify_author(resource)
      return if resource.hidden?

      resource.hide
      Activity.log(current_user, :hide, resource)
      Mailer.resource_hidden(resource).deliver_later if resource.author&.email.present?
    end
end
