require_dependency Rails.root.join("app", "models", "site_customization", "page").to_s

class SiteCustomization::Page < ApplicationRecord
  include ActionView::Helpers::SanitizeHelper

  self.inheritance_column = nil

  include Imageable
  attr_reader :origin

  belongs_to :projekt, touch: true

  has_many :comments, through: :projekt

  has_many :landing_projekts, class_name: 'Projekt', foreign_key: :landing_page_id
  has_many :landing_page_manager_assignments, foreign_key: :page_id, dependent: :destroy
  has_many :landing_page_managers, through: :landing_page_manager_assignments
  has_many :navbar_items, foreign_key: :landing_page_id, dependent: :destroy

  has_one_attached :landing_desktop_header_image
  has_one_attached :landing_mobile_header_image

  has_one_attached :landing_site_logo_for_transparent_background
  has_one_attached :landing_site_logo_for_white_background

  before_save :sanitize_title_and_subtitle
  before_save :set_published_at
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

  def sanitize_title_and_subtitle
    if title.present?
      # strip_tags could be imporant, since we have issue with copied text with rich html
      self.title = CGI.unescapeHTML(
        strip_tags(title).strip.gsub(/\A[[:space:]]+|[[:space:]]+\z/, '')
      )
    end

    if subtitle.present?
      self.subtitle = CGI.unescapeHTML(
        sanitize(subtitle, tags: ["br"]).gsub(/\A[[:space:]]+|[[:space:]]+\z/, '')
      )
    end
  end

  def set_published_at
    if status_changed? && status == 'published'
      self.published_at = Time.current
    end
  end

  def sync_projekt_for_global_overview
    return unless projekt.present?

    changed_set = saved_changes.except('created_at', 'updated_at')
    return if changed_set.empty?

    if projekt.should_be_exported_for_global_overview?
      if projekt.hidden_at.blank?
        Projekts::OverviewProjektUpdatedJob.perform_later(projekt)
      end
    end
  end
end
