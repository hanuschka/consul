class DeficiencyReport::ConfirmationPopup < ApplicationRecord
  self.table_name = "deficiency_report_confirmation_popups"

  has_many :answers,
    -> { order(position: :asc, id: :asc) },
    class_name: "DeficiencyReport::ConfirmationPopupAnswer",
    foreign_key: :confirmation_popup_id,
    inverse_of: :confirmation_popup,
    dependent: :destroy

  accepts_nested_attributes_for :answers,
    allow_destroy: true,
    reject_if: ->(attrs) { attrs[:label].blank? && attrs[:flash_notice].blank? }

  def self.current
    first || create!
  end

  def active?
    enabled? && question.present? && answers.any?
  end
end
