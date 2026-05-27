class SavedContentBlock < ApplicationRecord
  belongs_to :user, optional: true

  scope :global, -> { where(user_id: nil) }
  scope :for_user, ->(user) { where(user_id: user.id) }

  before_validation :repair_html_content, :sanitize_content

  def content_stripped?
    !!@content_stripped
  end

  private

  def repair_html_content
    return if content.blank?

    self.content = Nokogiri::HTML::DocumentFragment.parse(content).to_html
  end

  def sanitize_content
    return if content.blank?

    original = content
    self.content = AdminWYSIWYGSanitizer.new.sanitize(content)
    @content_stripped = original != content
  end
end
