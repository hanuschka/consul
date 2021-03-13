class Projekt < ApplicationRecord
  has_many :children, class_name: 'Projekt', foreign_key: 'parent_id'
  belongs_to :parent, class_name: 'Projekt', optional: true

  has_and_belongs_to_many :debates
  has_and_belongs_to_many :polls
  has_and_belongs_to_many :proposals
  has_and_belongs_to_many :budgets

  has_one :page, class_name: "SiteCustomization::Page", dependent: :destroy

  after_create :create_corresponding_page

  scope :top_level, -> { where(parent: nil) }

  def all_children_ids(all_children_ids = [])
    if self.children.any?
      self.children.each do |child|
        all_children_ids.push(child.id)
        child.all_children_ids(all_children_ids)
      end
    end

    all_children_ids
  end

  private

  def create_corresponding_page
    page_title = self.name
    last_page_id = SiteCustomization::Page.last.id
    clean_slug = self.name.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '-')
    page_slug = "#{clean_slug}_#{last_page_id}"
    page = SiteCustomization::Page.new(title: page_title, slug: page_slug, projekt: self)
    
    if page.save
      self.page = page
    end
  end
end
