class SavedContentBlock < ApplicationRecord
  belongs_to :user, optional: true

  scope :global, -> { where(user_id: nil) }
  scope :for_user, ->(user) { where(user_id: user.id) }

  before_validation :repair_html_content

  private

  def repair_html_content
    return if content.blank?

    self.content = Nokogiri::HTML::DocumentFragment.parse(content).to_html
  end
end
