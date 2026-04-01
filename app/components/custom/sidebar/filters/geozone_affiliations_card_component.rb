class Sidebar::Filters::GeozoneAffiliationsCardComponent < ApplicationComponent
  def initialize(districts:, resource_name:, selected_affiliated_districts:)
    @districts = districts
    @resource_name = resource_name
    @selected_affiliated_districts = selected_affiliated_districts
  end
end
