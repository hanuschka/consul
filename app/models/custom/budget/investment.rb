require_dependency Rails.root.join("app", "models", "budget", "investment").to_s

class Budget
  class Investment < ApplicationRecord
    delegate :projekt, to: :budget
  end
end
