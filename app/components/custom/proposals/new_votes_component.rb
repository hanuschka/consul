class Proposals::NewVotesComponent < ApplicationComponent
  delegate :user_signed_in?, :link_to_signin, :link_to_signup, :link_to_guest_signin, :link_to_enter_missing_user_data,
           :link_to_verify_account, :projekt_feature?, :projekt_phase_feature?, to: :helpers

  attr_reader :proposal, :vote_url, :proposal_ids
  delegate :current_user, :link_to_verify_account, to: :helpers

  def initialize(proposal, voted: nil, vote_url: nil, show_share_popup: false, proposal_ids: nil)
    @proposal = proposal
    @proposal_phase = @proposal.projekt_phase
    @vote_url = vote_url
    @voted = voted
    @show_share_popup = show_share_popup
    @proposal_ids = proposal_ids
  end

  def vote_url
    @vote_url || vote_proposal_path(proposal, value: "yes", offline_user_id: params[:offline_user_id])
  end

  # The ids of the cards currently on screen travel with the support and withdraw requests as
  # hidden fields, so the response can refresh all of them instead of only the clicked one:
  # crossing the phase's supports limit changes what every other card in the phase shows.
  # An empty list renders no hidden fields at all.
  #
  # show_share_popup travels too, because the vote response re-renders this card without knowing
  # which page it came from, and the popup only belongs on list cards - the show page renders the
  # same component without it.
  def refresh_params
    fields = {}
    # Only phases that actually have a limit send the ids: the response has nothing to do with
    # them otherwise, and they would be a hidden field per card on every proposal list.
    fields[:proposals_ids] = Array(proposal_ids) if @proposal_phase&.supports_limit_applies?
    fields[:show_share_popup] = true if @show_share_popup
    fields
  end

  def support_button_text
    @proposal_phase.support_button_text.presence ||
      t("proposals.proposal.support")
  end

  def supports_count
    I18n.t("custom.proposals.proposal.#{@proposal.projekt_phase.projekt.page.slug}.supports",
           count: proposal.total_votes,
           default: t("custom.proposals.proposal.default.supports", count: proposal.total_votes)
          )
  end

  private

    def voted?
      if @voted == true || @voted == false
        @voted
      else
        current_user&.voted_up_for?(proposal)
      end
    end

    def can_vote?
      proposal.votable_by?(current_user)
    end

    def permission_problem_key
      @permission_problem_key ||= @proposal_phase.permission_problem(current_user, location: :votes_component)
    end

    def cannot_vote_text
      return nil if permission_problem_key.blank?
      return nil if voted?
      return nil if @proposal_phase&.conditional_vote_possible_for?(current_user)

      t(path_to_key,
            sign_in: link_to_signin, sign_up: link_to_signup,
            guest_sign_in: link_to_guest_signin,
            enter_missing_user_data: link_to_enter_missing_user_data,
            verify: link_to_verify_account,
            city: Setting["org_name"],
            geozones: @proposal_phase&.geozone_restrictions_formatted,
            registered_address_groupings: @projekt_phase&.registered_address_grouping_restriction_formatted,
            age_restriction: @proposal_phase&.age_restriction_formatted,
            restricted_streets: @proposal_phase&.street_restrictions_formatted,
            individual_group_values: @proposal_phase&.individual_group_value_restriction_formatted,
            max_supports: @proposal_phase&.max_supports_per_user
      )
    end

    def path_to_key
      if @proposal_phase &&
        I18n.exists?("custom.projekt_phases.permission_problem.votes_component.#{@proposal_phase.name}.#{permission_problem_key}")
        "custom.projekt_phases.permission_problem.votes_component.#{@proposal_phase.name}.#{permission_problem_key}"
      else
        "custom.projekt_phases.permission_problem.votes_component.shared.#{permission_problem_key}"
      end
    end
end
