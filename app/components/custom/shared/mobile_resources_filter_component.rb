class Shared::MobileResourcesFilterComponent < ApplicationComponent
  def initialize(
    sdgs: nil, categories: nil, geozones: [],
    projekts_filter_variables: nil, resource_name:
  )
    @sdgs = sdgs
    @categories = categories
    @geozones = geozones
    @resource_name = resource_name
    @projekts_filter_variables = projekts_filter_variables
  end

  def render?
    false
  end
end
