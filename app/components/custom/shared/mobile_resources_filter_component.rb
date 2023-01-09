class Shared::MobileResourcesFilterComponent < ApplicationComponent
  def initialize(sdgs: nil, categories: nil, resource_name: nil)
    @sdgs = sdgs
    @categories = categories
    @resource_name = resource_name
  end
end
