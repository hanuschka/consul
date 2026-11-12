class Offer < ApplicationRecord
  include Mappable
  include Imageable

  REQUIRED_CATEGORY_KINDS = %w[offer_type social_area].freeze

  translates :title, touch: true
  translates :short_description, touch: true
  translates :times, touch: true
  translates :costs, touch: true
  translates :registration, touch: true
  include Globalizable

  belongs_to :author, class_name: "User", optional: true

  has_many :category_assignments, class_name: "Offer::CategoryAssignment", dependent: :destroy,
    inverse_of: :offer
  has_many :categories, through: :category_assignments, source: :category

  scope :sort_by_title, ->(direction = :asc) {
    locale = connection.quote(I18n.locale.to_s)
    direction = direction.to_s.casecmp?("desc") ? "DESC" : "ASC"

    reorder(Arel.sql(<<~SQL.squish))
      (SELECT t.title FROM offer_translations t
        WHERE t.offer_id = offers.id
        ORDER BY (t.locale = #{locale}) DESC, t.id ASC
        LIMIT 1) #{direction} NULLS LAST, offers.id #{direction}
    SQL
  }

  validates_translation :title, presence: true
  validate :short_description_present
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :contact_website, format: { with: %r{\Ahttps?://[^\s]+\z}i }, allow_blank: true
  validate :required_categories_present

  def categories_of(kind)
    categories.select { |category| category.kind == kind.to_s }
  end

  private

    def short_description_present
      return if Nokogiri::HTML5.fragment(short_description.to_s).text.tr(" ", " ").strip.present?

      errors.add(:short_description, :blank)
    end

    def required_categories_present
      selected_kinds = category_assignments.reject(&:marked_for_destruction?).map { |a| a.category&.kind }

      (REQUIRED_CATEGORY_KINDS - selected_kinds).each do |kind|
        errors.add(:base, I18n.t("activerecord.errors.models.offer.category_required",
                                 category: I18n.t("activerecord.attributes.offer/category.kinds.#{kind}")))
      end
    end
end
