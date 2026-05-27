class RecipientGroup < ApplicationRecord
  has_many :newsletters, dependent: :restrict_with_exception

  def self.base_options_for_kind
    %i[projekts user_roles]
  end

  def user_emails
    if origin_class_object_id.present?
      user_ids = origin_class_name.constantize
                                  .find_by(id: origin_class_object_id)
                                  .send(access_method.to_sym)
    else
      user_ids = origin_class_name.constantize
                                  .send(access_method.to_sym)
    end

    if access_method == "all_newsletter_subscriber_ids"
      [User.where(id: user_ids).pluck(:email) + UnregisteredNewsletterSubscriber.all.pluck(:email)]
        .flatten.compact.uniq
    else
      User.where(id: user_ids).pluck(:email).compact.uniq
    end
  end
end
