class Idea < ApplicationRecord
  include Mappable
  include Imageable
  include Documentable
  include Searchable
  include OnBehalfOfSubmittable

  belongs_to :author, class_name: "User", inverse_of: :ideas

  translates :title, :description
  include Globalizable

  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases

  acts_as_votable

  has_many :comments, as: :commentable, inverse_of: :commentable, dependent: :destroy

  validates :resource_terms, acceptance: { allow_nil: false }, on: :create

  scope :sort_by_most_supported, -> { reorder(cached_votes_up: :desc) }
  scope :sort_by_most_commented, -> { reorder(comments_count: :desc) }
  scope :sort_by_newest,         -> { reorder(created_at: :desc) }

  def self.idea_orders
    %w[most_supported most_commented newest]
  end

  def self.search(terms)
    pg_search(terms)
  end

  def searchable_values
    {
      id.to_s               => "A",
      author.username       => "B"
    }.merge!(searchable_globalized_values)
  end

  def searchable_translations_definitions
    { title       => "A",
      description => "D" }
  end

  def to_param
    "#{id}-#{title}".parameterize
  end

  def comments_allowed?(user)
    true
  end
end
