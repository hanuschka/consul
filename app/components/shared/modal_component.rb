class Shared::ModalComponent < ApplicationComponent
  attr_reader :id, :title, :closeable, :blur_backdrop, :close_on_backdrop,
    :close_on_esc, :content_wrapper, :modal_class, :data

  def initialize(
    id:,
    title: nil,
    closeable: true,
    blur_backdrop: true,
    close_on_backdrop: true,
    close_on_esc: true,
    content_wrapper: true,
    modal_class: nil,
    data: {}
  )
    @id = id
    @title = title
    @closeable = closeable
    @blur_backdrop = blur_backdrop
    @close_on_backdrop = close_on_backdrop
    @close_on_esc = close_on_esc
    @content_wrapper = content_wrapper
    @modal_class = modal_class
    @data = data
  end

  def css_classes
    classes = ["shared-modal"]
    classes << "-blur-backdrop" if blur_backdrop
    classes << modal_class if modal_class.present?
    classes.join(" ")
  end

  def dialog_data
    data.merge(
      no_backdrop_close: close_on_backdrop ? nil : "",
      no_esc_close: close_on_esc ? nil : ""
    ).compact
  end
end
