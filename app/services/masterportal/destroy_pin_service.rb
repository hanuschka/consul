class Masterportal::DestroyPinService < ApplicationService
  def initialize(masterportal_pin:)
    @masterportal_pin = masterportal_pin
  end

  def call
    associated = @masterportal_pin.associated_record
    deleted_resource = false

    ActiveRecord::Base.transaction do
      if associated.present?
        associated.destroy!
        deleted_resource = true
      end

      @masterportal_pin.destroy!
    end

    {
      deleted_pin: true,
      deleted_resource: deleted_resource
    }
  end
end
