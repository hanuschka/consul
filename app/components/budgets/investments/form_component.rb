class Budgets::Investments::FormComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper
  attr_reader :investment, :url
  delegate :current_user, :budget_heading_select_options, :suggest_data, :pick_text_color, :resources_back_link, to: :helpers

  def initialize(investment, url:)
    @investment = investment
    @url = url
  end

  private

    def budget
      investment.budget
    end

    def categories
      Tag.category.order(:name)
    end

    def title_placeholder
      investment.projekt_phase&.resource_form_title_placeholder.presence ||
        t("custom.budgets.investments.form.title_placeholder")
    end

    def description_placeholder
      investment.projekt_phase&.resource_form_description_placeholder.presence ||
        t("custom.budgets.investments.form.description_placeholder")
    end
end
