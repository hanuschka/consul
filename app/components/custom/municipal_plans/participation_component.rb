# frozen_string_literal: true

class MunicipalPlans::ParticipationComponent < ApplicationComponent
  attr_reader :municipal_plan, :projekts

  def initialize(municipal_plan:, projekts:)
    @municipal_plan = municipal_plan
    @projekts = projekts
  end

  def rows
    [
      {
        key: :formal,
        value: municipal_plan.formal_participation?,
        reason: municipal_plan.formal_participation_reason
      },
      {
        key: :informal,
        value: municipal_plan.informal_participation?,
        reason: municipal_plan.informal_participation_reason
      }
    ]
  end

  def several_projekts?
    projekts.size > 1
  end
end
