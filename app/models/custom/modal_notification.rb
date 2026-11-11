class ModalNotification < ApplicationRecord
  translates :title, :html_content
  include Globalizable

  audited
  has_associated_audits
  translation_class.class_eval do
    audited(
      associated_with: :globalized_model,
      only: %w[title html_content],
      if: ->(_translation) { Audit.translation_write_audited? }
    )
  end

  scope :active, ->(timestamp = Time.zone.today) {
    where("? BETWEEN active_from AND active_to", timestamp)
      .order(created_at: :desc)
  }

  def self.current
    active.first
  end
end
