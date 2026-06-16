class DeficiencyReport::ConfirmationPopupAnswer < ApplicationRecord
  self.table_name = "deficiency_report_confirmation_popup_answers"

  enum behavior: { allow: 0, block: 1 }

  belongs_to :confirmation_popup,
    class_name: "DeficiencyReport::ConfirmationPopup",
    inverse_of: :answers

  validates :label, presence: true
  validates :flash_notice, presence: true, if: :block?
end
