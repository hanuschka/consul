class Shared::LoadingModalComponent < ApplicationComponent
  attr_reader :id, :message, :note

  def initialize(id:, message:, note: nil)
    @id = id
    @message = message
    @note = note
  end
end
