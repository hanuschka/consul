class Ideas::VotesComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(idea)
    @idea = idea
  end

  private

    def progress_bar_percentage(idea)
      case idea.cached_votes_up
      when 0 then 0
      when 1..idea.votes_needed_for_success then (idea.cached_votes_up.to_f * 100 / idea.votes_needed_for_success).floor
      else 100
      end
    end

    def supports_percentage(idea)
      percentage = (idea.cached_votes_up.to_f * 100 / idea.votes_needed_for_success)
      case percentage
      when 0 then "0%"
      when 0..0.1 then "0.1%"
      when 0.1..100 then number_to_percentage(percentage, strip_insignificant_zeros: true, precision: 1)
      else "100%"
      end
    end
end
