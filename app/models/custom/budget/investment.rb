require_dependency Rails.root.join("app", "models", "budget", "investment").to_s
class Budget
  class Investment < ApplicationRecord
    include Search::Generic
  end
end