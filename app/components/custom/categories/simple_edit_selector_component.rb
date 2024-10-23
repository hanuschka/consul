class Categories::SimpleEditSelectorComponent < ApplicationComponent
  attr_reader :f

  def initialize(form)
    @f = form
  end
end
