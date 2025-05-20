class Idea::Officer < ApplicationRecord
  belongs_to :user

  def name
    user&.name || I18n.t("shared.author_info.author_deleted")
  end

  def email
    user&.email || I18n.t("shared.author_info.email_deleted")
  end
end
