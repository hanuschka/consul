class Shared::ModalComponent < ApplicationComponent
  attr_reader :id, :closeable, :blur_backdrop

  def initialize(id:, closeable: true, blur_backdrop: true)
    @id = id
    @closeable = closeable
    @blur_backdrop = blur_backdrop
  end

  def css_classes
    classes = ["shared-modal"]
    classes << "-blur-backdrop" if blur_backdrop
    classes.join(" ")
  end
end
