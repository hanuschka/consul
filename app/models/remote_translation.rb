class RemoteTranslation < ApplicationRecord
  belongs_to :remote_translatable, polymorphic: true

  validates :remote_translatable_id, presence: true
  validates :remote_translatable_type, presence: true
  validates :locale, presence: true
  validates :locale, inclusion: { in: ->(_) { MachineTranslation.translatable_locales.map(&:to_s) }}
  validate :translating_into_source_locale
  after_create :enqueue_remote_translation

  attr_accessor :source_locale

  def enqueue_remote_translation
    RemoteTranslations::Caller.new(self, source_locale: source_locale).delay.call
  end

  def self.remote_translation_enqueued?(remote_translation)
    where(remote_translatable_id: remote_translation["remote_translatable_id"],
          remote_translatable_type: remote_translation["remote_translatable_type"],
          locale: remote_translation["locale"],
          error_message: nil).any?
  end

  def translating_into_source_locale
    return if source_locale.blank?

    errors.add(:locale, :already_translated) if locale.to_s == source_locale.to_s
  end
end
