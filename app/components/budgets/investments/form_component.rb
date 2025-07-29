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

    def assistant_initial_data
      data = {
        resource_type: resource.class.name.downcase,
        projekt: {
          title: resource.projekt.page.title,
          page_content: resource.projekt.page_content,
          start_date: resource.projekt.total_duration_start,
          end_date: resource.projekt.total_duration_end
        },
        projekt_phase: {
          start_date: projekt_phase.start_date,
          end_date: projekt_phase.end_date
        }
      }

      if show_labels_selector? && projekt_phase.projekt_labels.present?
        data[:projekt_phase][:labels] =
          projekt_phase
          .projekt_labels
          .as_json(only: [:id], methods: [:name])
      end

      if show_sentiments_selector? && projekt_phase.sentiments.present?
        data[:projekt_phase][:sentiments] =
          projekt_phase
          .sentiments
          .as_json(only: [:id, :color], methods: [:name])
        # .as_json(only: [:id], methods: [:name])
      end

      data.to_json
    end

    def form_title
      investment.projekt_phase.resource_form_title.presence || t("custom.budgets.investments.form.start_new")
    end

    def form_description
      investment.projekt_phase.resource_form_intro.presence ||
        render_custom_block("user_resource_form_budget_investment",
                            default_content: t("custom.budgets.investments.form.page_description"))
    end

    def title_placeholder
      investment.projekt_phase&.resource_form_title_placeholder.presence ||
        t("custom.budgets.investments.form.title_placeholder")
    end

    def description_placeholder
      investment.projekt_phase&.resource_form_description_placeholder.presence ||
        t("custom.budgets.investments.form.description_placeholder")
    end

    def map_location
      investment.map_location ||
        investment.build_map_location(
          latitude: investment.projekt_phase&.map_location&.latitude,
          longitude: investment.projekt_phase&.map_location&.longitude,
          zoom: investment.projekt_phase&.map_location&.zoom
        )
    end
end
