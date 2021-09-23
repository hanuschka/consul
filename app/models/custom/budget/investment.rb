require_dependency Rails.root.join("app", "models", "budget", "investment").to_s

class Budget
  class Investment < ApplicationRecord
    attr_accessor :projekt_id

    def projekt
      budget.projekt
    end
  end
end
