class Shared::LoaderSpinnerWrapperComponent < ApplicationComponent
  attr_reader :loading, :size, :css_class

  def initialize(loading: false, size: "xlarge", css_class: nil)
    @loading = loading
    @size = size
    @css_class = css_class
  end

  def wrapper_classes
    classes = ["loader-spinner-wrapper"]

    if css_class.present?
      classes << css_class
    end

    if loading
      classes << "show-loader"
    end

    classes.join(" ")
  end
end
