# One case worker keeping an eye on one Anliegen — the bell in the backend. Its presence is what
# earns somebody the change notifications; removing it mutes that Anliegen for them without touching
# their access to it.
class DeficiencyReport::Watch < ApplicationRecord
  belongs_to :deficiency_report
  belongs_to :user

  validates :user_id, uniqueness: { scope: :deficiency_report_id }
end
