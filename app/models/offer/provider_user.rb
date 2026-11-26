class Offer::ProviderUser < ApplicationRecord
  belongs_to :provider, class_name: "Offer::Provider", foreign_key: :offer_provider_id, inverse_of: :provider_users
  belongs_to :user

  validates :user_id, uniqueness: { scope: :offer_provider_id }
end
