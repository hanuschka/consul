require_dependency Rails.root.join("app", "models", "site_customization", "page").to_s

class SiteCustomization::Page < ApplicationRecord
  include Search::Generic
  include ActionView::Helpers::SanitizeHelper

  self.inheritance_column = nil

  include Imageable
  include SectionTrackable
  attr_reader :origin

  belongs_to :projekt, touch: true

  has_many :comments, through: :projekt

  has_many :landing_projekts, class_name: 'Projekt', foreign_key: :landing_page_id, dependent: :nullify
  has_many :landing_page_manager_assignments, foreign_key: :page_id, dependent: :destroy
  has_many :landing_page_managers, through: :landing_page_manager_assignments
  has_many :navbar_items, foreign_key: :landing_page_id, dependent: :destroy
  has_many :content_cards, class_name: "SiteCustomization::ContentCard",
                           foreign_key: :landing_page_id, dependent: :destroy

  has_one_attached :landing_desktop_header_image
  has_one_attached :landing_mobile_header_image

  has_one_attached :landing_desktop_header_video
  has_one_attached :landing_mobile_header_video

  has_one_attached :landing_site_logo_for_transparent_background
  has_one_attached :landing_site_logo_for_white_background

  LANDING_VIDEO_FORMATS = ["video/mp4", "video/webm"].freeze
  LANDING_VIDEO_MAX_SIZE = 50.megabytes

  # Pages linked from the public footer. footer_key is the immutable identity
  # of a footer page (slug and title are admin-editable).
  FOOTER_KEYS = %w[privacy additional_privacy conditions accessibility impressum
                   netiquette contact_us open_source].freeze

  validates :footer_key, uniqueness: true, inclusion: { in: FOOTER_KEYS }, allow_nil: true

  scope :footer_pages, -> { where(footer_key: FOOTER_KEYS).reorder(:footer_position, :id) }

  def self.order_footer_pages(ordered_ids)
    pages_by_id = footer_pages.where(id: ordered_ids).index_by(&:id)

    transaction do
      ordered_ids.each_with_index do |page_id, index|
        pages_by_id[page_id.to_i]&.update_column(:footer_position, index + 1)
      end
    end
  end

  validates :landing_desktop_header_video,
            file_content_type: { allow: LANDING_VIDEO_FORMATS, if: -> { landing_desktop_header_video.attached? }},
            file_size: { less_than_or_equal_to: LANDING_VIDEO_MAX_SIZE, if: -> { landing_desktop_header_video.attached? }}
  validates :landing_mobile_header_video,
            file_content_type: { allow: LANDING_VIDEO_FORMATS, if: -> { landing_mobile_header_video.attached? }},
            file_size: { less_than_or_equal_to: LANDING_VIDEO_MAX_SIZE, if: -> { landing_mobile_header_video.attached? }}

  before_save :sanitize_title
  before_validation :normalize_subtitle
  validate :subtitle_within_limits
  before_save :capture_old_title
  before_save :set_published_at
  after_update :sync_projekt_name
  after_update :sync_projekt_for_global_overview

  scope :regular, -> {
    where(landing: false)
  }

  scope :landing, -> {
    where(landing: true)
  }

  scope :landing_show_in_top_nav, -> {
    where(landing_show_in_top_nav: true)
  }

  def draft?
    status == 'draft'
  end

  def published?
    status == 'published'
  end

  def comments_count
    comments.count
  end

  def elastic_searchable?
    published?
  end

  def full_url
    Setting['url'].chomp('/') + "/#{slug}"
  end

  def safe_to_destroy?
    projekt.blank?
  end

  def self.order_landing_pages(ordered_array)
    ordered_array.each_with_index do |page_id, position|
      find(page_id).update_column(:landing_nav_position, (position + 1))
    end
  end

  def sanitize_title
    return if title.blank?

    # strip_tags could be imporant, since we have issue with copied text with rich html
    self.title = CGI.unescapeHTML(
      strip_tags(title).strip.gsub(/\A[[:space:]]+|[[:space:]]+\z/, '')
    )
  end

  def normalize_subtitle
    return if subtitle.blank?

    self.subtitle = sanitize(
      MultilineSubtitleNormalizer.normalize(subtitle),
      tags: ["br"],
      attributes: []
    )
  end

  def subtitle_within_limits
    return if subtitle.blank?

    if MultilineSubtitleNormalizer.visible_length(subtitle) > MultilineSubtitleNormalizer::MAX_VISIBLE_LENGTH
      errors.add(:subtitle, :too_long, count: MultilineSubtitleNormalizer::MAX_VISIBLE_LENGTH)
    end

    if MultilineSubtitleNormalizer.line_break_count(subtitle) > MultilineSubtitleNormalizer::MAX_LINE_BREAKS
      errors.add(:subtitle, :too_many_lines, count: MultilineSubtitleNormalizer::MAX_LINE_BREAKS + 1)
    end
  end

  def set_published_at
    if status_changed? && status == 'published'
      self.published_at = Time.current
    end
  end

  def section_tracking_section
    "landing_pages"
  end

  def section_tracking_user
    nil
  end

  def capture_old_title
    @old_title = projekt&.name if title_changed?
  end

  def sync_projekt_name
    return unless projekt.present? && @old_title

    new_title = title

    projekt.update_column(:name, new_title)

    projekt.polls.each do |poll|
      next unless poll.name.present?

      suffix = poll.name.delete_prefix(@old_title).strip
      poll.update(name: [new_title, suffix.presence].compact.join(" "))
    end

    @old_title = nil
  end

  def sync_projekt_for_global_overview
    projekt&.sync_for_global_overview_from_page_changes(saved_changes)
  end
end
