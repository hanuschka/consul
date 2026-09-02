class DeficiencyReport::IntakeChannel < ApplicationRecord
  translates :name, touch: true
  include Globalizable

  has_many :deficiency_reports, foreign_key: :deficiency_report_intake_channel_id

  default_scope { order(given_order: :asc) }

  validates_translation :name, presence: true

  after_save :unset_other_defaults, if: :default?

  # The value citizen submissions are stamped with. Falls back to the first channel so a client who
  # never marked one still gets a consistent value instead of a blank.
  def self.default
    find_by(default: true) || first
  end

  def self.order_intake_channels(ordered_array)
    ordered_array.each_with_index do |intake_channel_id, order|
      find(intake_channel_id).update_column(:given_order, (order + 1))
    end
  end

  def safe_to_destroy?
    !deficiency_reports.exists?
  end

  private

    def unset_other_defaults
      self.class.unscoped.where.not(id: id).update_all(default: false)
    end
end
