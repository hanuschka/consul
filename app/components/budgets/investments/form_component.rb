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
end
