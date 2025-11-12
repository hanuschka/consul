class Idea::Officer < ApplicationRecord
  belongs_to :user
  has_many :ideas, foreign_key: :idea_officer_id, inverse_of: :officer, dependent: :nullify

  def name
    user&.name || I18n.t("shared.author_info.author_deleted")
  end

  def email
    user&.email || I18n.t("shared.author_info.email_deleted")
  end
end
