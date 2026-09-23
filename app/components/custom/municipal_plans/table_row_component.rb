# frozen_string_literal: true

class MunicipalPlans::TableRowComponent < MunicipalPlans::ListItemComponent
  COLUMN_KEYS = %i[name tags content_updated_at topics districts].freeze

  def self.columns
    COLUMN_KEYS.map do |key|
      { key: key, label: I18n.t("custom.municipal_plans.index.table.columns.#{key}") }
    end
  end

  def label_for(key)
    I18n.t("custom.municipal_plans.index.table.columns.#{key}")
  end

  def content_updated_at
    return if municipal_plan.content_updated_at.blank?

    l(municipal_plan.content_updated_at, format: "%d.%m.%Y")
  end
end
