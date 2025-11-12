class GraphqlUser < ApplicationRecord
  before_create :generate_auth_token

  belongs_to :user

  private

    def generate_auth_token
      self.auth_token = SecureRandom.hex(20)
    end
end
