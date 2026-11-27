class RecipientGroup < ApplicationRecord
  belongs_to :projekt, optional: true
  has_many :newsletters, dependent: :restrict_with_exception
  has_many :filters,
           -> { order(:position) },
           class_name: "RecipientGroupFilter",
           dependent: :destroy,
           inverse_of: :recipient_group

  validates :name, presence: true

  scope :with_projekt_titles, -> { includes(projekt: { page: :translations }) }

  def self.base_options_for_kind
    %i[projekts user_roles]
  end

  def projekt_subscribers_group?
    projekt_id.present?
  end

  def projekt_subscribers_audience?
    if filters.any?
      filters.all? { it.kind == "projekt_subscribers" }
    else
      origin_class_name == "Projekt" && access_method == "subscriber_ids"
    end
  end

  def display_name
    return name if projekt.blank?

    I18n.t("adm.recipient_groups.projekt_subscribers_group_name", title: projekt.title)
  end

  def user_emails
    if filters.any?
      RecipientGroupResolver.new(self).user_emails
    else
      legacy_user_emails
    end
  end

  private

    def legacy_user_emails
      return [] if origin_class_name.blank? || access_method.blank?

      if origin_class_object_id.present?
        user_ids = origin_class_name.constantize
                                    .find_by(id: origin_class_object_id)
                                    .send(access_method.to_sym)
      else
        user_ids = origin_class_name.constantize.send(access_method.to_sym)
      end

      if access_method == "all_newsletter_subscriber_ids"
        [User.where(id: user_ids).pluck(:email) + UnregisteredNewsletterSubscriber.all.pluck(:email)]
          .flatten.compact.uniq
      else
        User.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
end
