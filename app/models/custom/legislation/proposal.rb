require_dependency Rails.root.join("app", "models", "legislation", "proposal").to_s
class Legislation::Proposal < ApplicationRecord
  include Search::Generic
end