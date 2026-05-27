class Masterportal::DestroyAllPinsService < ApplicationService
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    deleted_pins_count = 0
    deleted_resources_count = 0

    ActiveRecord::Base.transaction do
      @projekt_phase
        .masterportal_pins
        .includes(:proposal, :budget_investment, :projekt_point_of_interest_pin)
        .find_each do |pin|
          associated = pin.associated_record

          if associated.present?
            associated.destroy!
            deleted_resources_count += 1
          end

          pin.destroy!
          deleted_pins_count += 1
        end
    end

    {
      deleted_pins_count: deleted_pins_count,
      deleted_resources_count: deleted_resources_count
    }
  end
end
