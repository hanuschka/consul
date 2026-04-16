class Adm::ConnectionBadgeComponent < ViewComponent::Base
  def initialize(status:, icon:, label:, description:, hint:, error: nil)
    @status = status
    @icon = icon
    @label = label
    @description = description
    @hint = hint
    @error = error
  end

  private

  attr_reader :status, :icon, :label, :description, :hint, :error
end
