# frozen_string_literal: true

class MunicipalPlans::ListItemComponent < ApplicationComponent
  PARTICIPATION_KINDS = %w[formal informal].freeze

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

  def topic_names
    municipal_plan.topics.map(&:name)
  end

  def district_names
    municipal_plan.districts.map(&:name_for_display)
  end

  def participation_enabled?(kind)
    municipal_plan.public_send("#{kind}_participation")
  end

  def participation_icon_class(kind)
    participation_enabled?(kind) ? "fa-check" : "fa-times"
  end
end
