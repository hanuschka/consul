class SavedContentBlock < ApplicationRecord
  belongs_to :user, optional: true

  scope :global, -> { where(user_id: nil) }
  scope :for_user, ->(user) { where(user_id: user.id) }
end
