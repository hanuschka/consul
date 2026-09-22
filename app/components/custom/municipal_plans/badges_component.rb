# frozen_string_literal: true

class MunicipalPlans::BadgesComponent < ApplicationComponent
  ICONS = {
    new: "star",
    updated: "sync-alt",
    formal_participation: "balance-scale",
    informal_participation: "hands-helping"
  }.freeze

  attr_reader :municipal_plan

  def initialize(municipal_plan:)
    @municipal_plan = municipal_plan
  end

  def render?
    badges.any?
  end

  def badges
    @badges ||= municipal_plan.badges
  end

  def icon_class(badge)
    ICONS.fetch(badge, "circle")
  end

  def modifier_class(badge)
    "municipal-plan-badge--#{badge.to_s.dasherize}"
  end
end
