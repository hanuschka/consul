load Rails.root.join("app", "models", "legislation", "question.rb")

class Legislation::Question < ApplicationRecord
  delegate :projekt, to: :process, allow_nil: true
end
