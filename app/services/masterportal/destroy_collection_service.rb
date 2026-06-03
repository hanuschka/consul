class Masterportal::DestroyCollectionService < ApplicationService
  def initialize(masterportal_collection:)
    @collection = masterportal_collection
  end

  def call
    start_destroy!

    result = destroy_pins_and_collection

    result
  rescue => e
    Sentry.capture_exception(e) if defined?(Sentry)
    finalize_failure!(e)
    raise
  end

  private

    def start_destroy!
      @collection.update!(destroy_status: "running", destroy_error: nil)
    end

    def destroy_pins_and_collection
      deleted_pins_count = 0
      deleted_resources_count = 0

      ActiveRecord::Base.transaction do
        @collection
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

        @collection.destroy!
      end

      {
        deleted_pins_count: deleted_pins_count,
        deleted_resources_count: deleted_resources_count
      }
    end

    def finalize_failure!(error)
      return if @collection.destroyed?

      @collection.update!(
        destroy_status: "failed",
        destroy_error: error.message.truncate(1000)
      )
    end
end
