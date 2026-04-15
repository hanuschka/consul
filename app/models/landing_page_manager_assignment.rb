class LandingPageManagerAssignment < ApplicationRecord
  belongs_to :page, class_name: "SiteCustomization::Page"
  belongs_to :landing_page_manager
end
