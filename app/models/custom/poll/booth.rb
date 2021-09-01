require_dependency Rails.root.join("app", "models", "poll", "booth").to_s

class Poll
  class Booth < ApplicationRecord
    def self.available
      where(polls: { id: Poll.current_or_recounting }).joins(:polls).distinct
    end
  end
end
