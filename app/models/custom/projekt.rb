class Projekt < ApplicationRecord
  has_many :children, class_name: 'Projekt', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Projekt', optional: true

  has_and_belongs_to_many :debates
  has_and_belongs_to_many :polls
  has_and_belongs_to_many :proposals
  has_and_belongs_to_many :budgets

  after_create :create_corresponding_page

  private

  def create_corresponding_page
    page_title = self.name
    page_slug = self.name.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '-')
    SiteCustomization::Page.
  end
end
