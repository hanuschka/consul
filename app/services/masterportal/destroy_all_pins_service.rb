class Masterportal::DestroyAllPinsService < ApplicationService
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    start_destroy!

    result = destroy_pins

    finalize_success!
    result
  rescue => e
    Sentry.capture_exception(e) if defined?(Sentry)
    finalize_failure!(e)
    raise
  end

  private

    def start_destroy!
      @projekt_phase.update!(
        masterportal_destroy_status: "running",
        masterportal_destroy_error: nil
      )
    end

    def destroy_pins
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

    def finalize_success!
      @projekt_phase.update!(masterportal_destroy_status: "success")
    end

    def finalize_failure!(error)
      @projekt_phase.update!(
        masterportal_destroy_status: "failed",
        masterportal_destroy_error: error.message.truncate(1000)
      )
    end
end
