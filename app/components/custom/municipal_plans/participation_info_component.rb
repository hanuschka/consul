# frozen_string_literal: true

class MunicipalPlans::ParticipationInfoComponent < ApplicationComponent
  attr_reader :kind

  def initialize(kind:)
    @kind = kind
  end

  def label
    t("custom.municipal_plans.participation_info.#{kind}.label")
  end

  def text
    t("custom.municipal_plans.participation_info.#{kind}.text")
  end
end
