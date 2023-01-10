class Shared::MobileResourcesFilterComponent < ApplicationComponent
  def initialize(sdgs: nil, categories: nil, geozones: [], resource_name:)
    @sdgs = sdgs
    @categories = categories
    @geozones = geozones
    @resource_name = resource_name
  end
end
