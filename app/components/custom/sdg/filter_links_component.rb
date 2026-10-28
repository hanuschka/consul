load Rails.root.join("app", "components", "sdg", "filter_links_component.rb")

class SDG::FilterLinksComponent < ApplicationComponent
  delegate :link_list_sdg_goals, to: :helpers
end
