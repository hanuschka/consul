class Shared::AccordionComponent < ApplicationComponent
  renders_one :head
  renders_one :body

  def initialize(opened_by_default: false, root_class: nil)
    @opened_by_default = opened_by_default
    @root_class = root_class
  end
end
