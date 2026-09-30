# frozen_string_literal: true

class MunicipalPlans::ListItemComponent < ApplicationComponent
  attr_reader :municipal_plan

  def initialize(municipal_plan:)
    @municipal_plan = municipal_plan
  end

  def component_attributes
    {
      resource: municipal_plan,
      title: municipal_plan.title,
      description: municipal_plan.short_description,
      url: helpers.municipal_plan_path(municipal_plan),
      title_heading_level: 2
    }
  end

  def topics
    municipal_plan.topics
  end

  def topic_path(topic)
    helpers.municipal_plans_path(topics: [topic.id])
  end

  def district_names
    municipal_plan.districts.map(&:name_for_display)
  end

  def header_label
    date = l(municipal_plan.display_updated_on, format: "%d.%m.%Y")

    t("custom.municipal_plans.index.updated_on", date: date)
  end
end
