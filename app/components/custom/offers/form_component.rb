class Offers::FormComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper

  attr_reader :offer, :categories_by_kind, :providers
  delegate :back_link_to, :ck_editor_class, to: :helpers

  def initialize(offer, categories_by_kind:, providers:)
    @offer = offer
    @categories_by_kind = categories_by_kind
    @providers = providers
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

  def show_provider_select?
    administrator? || (offer.new_record? && providers.many?)
  end

  def provider_choices
    providers.map { |provider| [provider.name, provider.id] }
  end

  def provider_select_options
    options = { hint: t("custom.offers.form.hints.provider") }

    if administrator?
      options.merge(label: Offer.human_attribute_name(:provider),
                    include_blank: t("custom.offers.form.provider_blank"))
    else
      options.merge(label: required_label(Offer.human_attribute_name(:provider)),
                    prompt: t("custom.offers.form.provider_prompt"))
    end
  end

  def required_label(text)
    "#{text} #{t("custom.offers.form.required")}"
  end

  private

    def administrator?
      current_user.administrator?
    end
end
