class Formular < ApplicationRecord
  belongs_to :projekt_phase
  has_many :formular_fields, dependent: :destroy
  has_many :formular_answers, dependent: :destroy
  has_many :formular_follow_up_letters, dependent: :destroy

  def past_cutoff_date?
    return false if projekt_phase.regular_formular_cutoff_date.nil?

    projekt_phase.regular_formular_cutoff_date < Time.zone.now.to_date
  end

  def submissions_limit_reached_for?(user)
    limit = projekt_phase.settings.find_by(key: "option.general.submissions_limit").value.to_i
    formular_answers.where(submitter_id: user.id).count >= limit
  end
end
