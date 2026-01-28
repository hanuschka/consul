class ProjektManagerAssignment < ApplicationRecord
  belongs_to :projekt, touch: true
  belongs_to :projekt_manager

  ACCEPTABLE_PERMISSIONS = %w[manage moderate create_on_behalf_of get_notifications access_graphql review].freeze

  default_scope { order(id: :asc) }
end
