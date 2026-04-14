require_dependency Rails.root.join("app", "models", "legislation", "question").to_s

class Legislation::Question < ApplicationRecord
  delegate :projekt, to: :process, allow_nil: true
end
