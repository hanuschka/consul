load Rails.root.join("app", "models", "legislation", "proposal.rb")

class Legislation::Proposal < ApplicationRecord
  # validates :terms_of_service, acceptance: { allow_nil: false }, on: :create
  validates :resource_terms, acceptance: { allow_nil: false }, on: :create #custom

  delegate :projekt, to: :process, allow_nil: true
end
