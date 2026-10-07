# frozen_string_literal: true

class MunicipalPlans::HeroComponent < ApplicationComponent
  attr_reader :municipal_plan

  def initialize(municipal_plan:)
    @municipal_plan = municipal_plan
  end

  def status_label
    if municipal_plan.archived?
      t("custom.municipal_plans.show.hero.status_archived_chip")
    elsif municipal_plan.newly_added?
      t("custom.municipal_plans.show.hero.status_new")
    elsif municipal_plan.recently_updated?
      t("custom.municipal_plans.show.hero.status_updated")
    end
  end

  def sorted_topics
    @sorted_topics ||= municipal_plan.topics.select { |topic| topic.name.present? }
                                            .sort_by { |topic| MunicipalPlan.name_sort_key(topic.name) }
  end

  def topic_path(topic)
    helpers.municipal_plans_path(topics: [topic.id])
  end

  def district_names
    municipal_plan.sorted_district_names
  end

  def updated_on_label
    date = l(municipal_plan.display_updated_on, format: "%d.%m.%Y")

    t("custom.municipal_plans.show.updated_on", date: date)
  end

  def chips?
    status_label.present? || sorted_topics.any?
  end
end
