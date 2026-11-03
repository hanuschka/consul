class RemoteTranslation < ApplicationRecord
  belongs_to :remote_translatable, polymorphic: true

  validates :remote_translatable_id, presence: true
  validates :remote_translatable_type, presence: true
  validates :locale, presence: true
  validates :locale, inclusion: { in: ->(_) { MachineTranslation.deepl_locales.map(&:to_s) }}
  validate :translating_into_source_locale
  before_create :discard_failed_attempts
  after_create :enqueue_remote_translation

  attr_accessor :source_locale, :backfill

  def enqueue_remote_translation
    RemoteTranslations::Caller.new(self, source_locale: source_locale, backfill: backfill.present?)
                             .delay.call
  end

  def discard_failed_attempts
    RemoteTranslation.where(remote_translatable_type:, remote_translatable_id:, locale:)
                     .where.not(error_message: nil)
                     .delete_all
  end

  def translating_into_source_locale
    return if source_locale.blank?

    errors.add(:locale, :already_translated) if locale.to_s == source_locale.to_s
  end
end
