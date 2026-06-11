class Masterportal::LabelAssigner < ApplicationService
  DEFAULT_ICON = "tag".freeze

  def initialize(record:, pin:, labels_by_name: {})
    @record = record
    @pin = pin
    @labels_by_name = labels_by_name
  end

  def call
    name = Masterportal::CategoryNameResolver.call(pin: @pin)
    return if name.blank?

    @record.projekt_labels = [find_or_create_label(name)]
  end

  private

    def find_or_create_label(name)
      @labels_by_name[name] ||= existing_label(name) || create_label(name)
    end

    def existing_label(name)
      @pin.projekt_phase.projekt_labels
        .joins(:translations)
        .where(projekt_label_translations: { locale: I18n.locale.to_s, name: name })
        .first
    end

    def create_label(name)
      @pin.projekt_phase.projekt_labels.create!(name: name, icon: DEFAULT_ICON)
    end
end
