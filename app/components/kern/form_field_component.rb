class Kern::FormFieldComponent < ApplicationComponent
  def initialize(label:, hint: nil, turbo_frame_id: nil)
    @label = label
    @hint = hint
    @turbo_frame_id = turbo_frame_id
  end

  attr_reader :label, :hint, :turbo_frame_id
end
