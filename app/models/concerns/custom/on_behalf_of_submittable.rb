module OnBehalfOfSubmittable
  extend ActiveSupport::Concern

  included do
    # Filled in by staff on the internal forms next to on_behalf_of. They are not stored on the
    # resource: the email resolves to the User the resource gets attributed to, and the company
    # name is kept on that user's profile.
    attr_accessor :on_behalf_of_company_name, :on_behalf_of_email

    validates :on_behalf_of_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  end

  def author_name
    return User.human_attribute_name(:guest) if author.guest?

    on_behalf_of.presence || author.name
  end

  def author_initial
    if on_behalf_of.present?
      on_behalf_of.chars&.first&.upcase
    else
      author.first_letter_of_name
    end
  end
end
