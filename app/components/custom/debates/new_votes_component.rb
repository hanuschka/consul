class Debates::NewVotesComponent < ApplicationComponent
  delegate :user_signed_in?, :link_to_signin, :link_to_signup,
           :link_to_verify_account, :projekt_feature?, :projekt_phase_feature?, to: :helpers

  attr_reader :debate
  delegate :current_user, :link_to_verify_account, to: :helpers

  def initialize(debate)
    @debate = debate
    @debate_phase = debate.projekt_phase
  end

  private

    def can_vote?
      debate.votable_by?(current_user)
    end

    def permission_problem_key
      @permission_problem_key ||= @debate_phase.permission_problem(current_user, location: :votes_component)
    end

    def cannot_vote_text
      return nil if permission_problem_key.blank?

      if permission_problem_key == :not_logged_in
        t(path_to_key,
          sign_in: link_to_signin, sign_up: link_to_signup)

      else
        t(path_to_key,
              verify: link_to_verify_account,
              city: Setting["org_name"],
              geozones: @debate_phase&.geozone_restrictions_formatted,
              age_restriction: @debate_phase&.age_restriction_formatted,
              restricted_streets: @debate_phase&.street_restrictions_formatted,
              individual_group_values: @debate_phase&.individual_group_value_restriction_formatted
        )
      end
    end

    def path_to_key
      if @debate_phase &&
        I18n.exists?("custom.projekt_phases.permission_problem.votes_component.#{@debate_phase.name}.#{permission_problem_key}")
        "custom.projekt_phases.permission_problem.votes_component.#{@debate_phase.name}.#{permission_problem_key}"
      else
        "custom.projekt_phases.permission_problem.votes_component.shared.#{permission_problem_key}"
      end
    end
end
