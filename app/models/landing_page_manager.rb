class LandingPageManager < ApplicationRecord
  belongs_to :user, touch: true
  delegate :name, :email, :name_and_email, to: :user

  has_many :landing_page_manager_assignments, dependent: :destroy
  has_many :pages, through: :landing_page_manager_assignments

  validates :user_id, presence: true, uniqueness: true

  def allowed_to?(page)
    return true if manage_all_landing_pages?
    return false unless page.present?

    landing_page_manager_assignments.exists?(page_id: page.id)
  end
end
