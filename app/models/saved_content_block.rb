class SavedContentBlock < ApplicationRecord
  CONTEXTS = %w[projekt newsletter].freeze

  belongs_to :user, optional: true

  validates :context, inclusion: { in: CONTEXTS }

  scope :global, -> { where(user_id: nil) }
  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :for_context, ->(context) { where(context: context) }

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

    sanitizer = AdminWYSIWYGSanitizer.new
    original = content
    self.content = sanitizer.sanitize(content)
    @content_stripped = sanitizer.stripped?(original, content)
  end
end
