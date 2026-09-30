# frozen_string_literal: true

class MunicipalPlans::StatusTimelineComponent < ApplicationComponent
  attr_reader :municipal_plan

  def initialize(municipal_plan:)
    @municipal_plan = municipal_plan
  end

  def render?
    stations.any?
  end

  def stations
    @stations ||= begin
      present = [
        { key: :last_resolution, icon: "gavel", value: municipal_plan.last_resolution },
        { key: :processing_status, icon: "map-marker-alt", value: municipal_plan.processing_status,
          current: true },
        { key: :next_steps, icon: "flag", value: municipal_plan.next_steps, upcoming: true }
      ].select { |station| strip_tags(station[:value].to_s).strip.present? }

      present.each_with_index.map do |station, index|
        station.merge(dashed_connector: present[index + 1]&.dig(:upcoming).present?)
      end
    end
  end

  def station_classes(station)
    [
      "municipal-plan-timeline--station",
      ("-current" if station[:current]),
      ("-upcoming" if station[:upcoming]),
      ("-dashed-connector" if station[:dashed_connector])
    ].compact.join(" ")
  end

  def updated_on_label
    date = l(municipal_plan.display_updated_on, format: "%d.%m.%Y")

    t("custom.municipal_plans.show.updated_on", date: date)
  end
end
