class Shared::AdminIframeComponent < ApplicationComponent
  attr_reader :src, :css_class, :allow, :title, :referrerpolicy

  def initialize(src:, css_class: nil, allow: nil, title: nil, referrerpolicy: nil)
    @src = src
    @css_class = css_class
    @allow = allow
    @title = title
    @referrerpolicy = referrerpolicy
  end

  def iframe_classes
    classes = ["shared-admin-iframe"]
    classes << css_class if css_class.present?

    classes.join(" ")
  end
end
