class Offers::FormComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper

  attr_reader :offer, :categories_by_kind
  delegate :back_link_to, :ck_editor_class, to: :helpers

  def initialize(offer, categories_by_kind:)
    @offer = offer
    @categories_by_kind = categories_by_kind
  end

  def title
    if offer.new_record?
      t("custom.offers.new.title")
    else
      t("custom.offers.edit.title")
    end
  end

  def submit_text
    if offer.new_record?
      t("custom.offers.form.submit.new")
    else
      t("custom.offers.form.submit.edit")
    end
  end

  def categories_for(kind)
    categories_by_kind.fetch(kind, [])
  end

  def required_kind?(kind)
    Offer::REQUIRED_CATEGORY_KINDS.include?(kind)
  end

  def required_label(text)
    "#{text} #{t("custom.offers.form.required")}"
  end
end
