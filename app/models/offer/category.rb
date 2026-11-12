class Offer::Category < ApplicationRecord
  KINDS = %w[offer_type target_group costs accessibility social_area].freeze

  translates :name, touch: true
  include Globalizable

  has_many :category_assignments, class_name: "Offer::CategoryAssignment",
    foreign_key: :offer_category_id, dependent: :destroy, inverse_of: :category
  has_many :offers, through: :category_assignments

  validates :kind, inclusion: { in: KINDS }
  validates_translation :name, presence: true

  default_scope { order(given_order: :asc, id: :asc) }

  scope :of_kind, ->(kind) { where(kind: kind.to_s) }

  before_destroy :ensure_not_in_use, prepend: true

  def safe_to_destroy?
    !offers.exists?
  end

  def self.order_categories(ordered_ids)
    ordered_ids.each_with_index do |id, order|
      find(id).update_column(:given_order, order + 1)
    end
  end

  private

    def ensure_not_in_use
      return if safe_to_destroy?

      errors.add(:base, I18n.t("activerecord.errors.messages.restrict_dependent_destroy.has_many",
                               record: Offer.model_name.human(count: 2)))
      throw :abort
    end
end
