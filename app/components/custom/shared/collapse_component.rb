class Shared::CollapseComponent < ApplicationComponent
  renders_one :head
  renders_one :body

  def initialize(opened_by_default: false, head_hover_background: false, head_background: false)
    @opened_by_default = opened_by_default
    @head_hover_background = head_hover_background
    @head_background = head_background
  end
end
