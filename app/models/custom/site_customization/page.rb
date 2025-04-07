require_dependency Rails.root.join("app", "models", "site_customization", "page").to_s

class SiteCustomization::Page < ApplicationRecord
  self.inheritance_column = nil

  include Imageable
  attr_reader :origin

  belongs_to :projekt, touch: true

  has_many :comments, through: :projekt

  has_and_belongs_to_many :landing_projekts,
    join_table: 'landing_pages_projekts',
    foreign_key: 'site_customization_page_id',
    association_foreign_key: 'projekt_id',
    class_name: "Projekt"

  has_one_attached :landing_mobile_header_image

  has_one_attached :landing_site_logo_for_transparent_background
  has_one_attached :landing_site_logo_for_white_background

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
end
