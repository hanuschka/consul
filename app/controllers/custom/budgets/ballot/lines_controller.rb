require_dependency Rails.root.join("app", "controllers", "budgets", "ballot", "lines_controller").to_s

module Budgets
  module Ballot
    class LinesController < ApplicationController
      private

        def load_ballot
          user = User.find_by(id: params[:user_id]) || current_user
          @ballot = Budget::Ballot.where(user: user, budget: @budget).first_or_create!
        end
    end
  end
end
