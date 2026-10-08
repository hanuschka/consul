module Whatsapp::StatePills
  # The pills a reply about one proposal or projekt carries whatever the model chose
  # to offer: a proposal the citizen supports comes with "Zurücknehmen", one they do
  # not support yet with "Jetzt unterstützen", one open for comments with
  # "Kommentieren", and a projekt with following or unfollowing it. The words above
  # them stay the model's; which of these sit under them is read off the state.
  #
  # Left to the model, the same proposal in the same state came with the withdraw
  # pill on one reply and with only its link and "you can take it back on the page"
  # on the next, and the comment pill was not offered at all. The labels were already
  # fixed (Whatsapp::AssistantActions::FORCED_LABEL_ACTIONS); the offer was not.
  #
  # Put ahead of the model's own pills, which fill the slots that are left: the
  # state pills are the ones the citizen has to be able to rely on finding.
  #
  # A reply right after a submission carries what follows from it instead: another
  # idea, their own contributions and the projekts. Left to the model, it suggested
  # another idea in words while the slots went to the support and comment pills of
  # the proposal just published — the citizen's own, which they cannot support.

  # Every slot a message has, so the reply's pills are these three and no others.
  SUBMISSION_COMPLETED_ACTIONS = %i[submit_proposal my_contributions discover].freeze

  module_function

  def focus_submission_completed
    ::Current.whatsapp_pill_focus = { submission_completed: true }
  end

  def focus_proposal(proposal_id)
    return if proposal_id.blank?

    ::Current.whatsapp_pill_focus = { proposal_id: proposal_id.to_i }
  end

  def focus_projekt(projekt_id)
    return if projekt_id.blank?

    ::Current.whatsapp_pill_focus = { projekt_id: projekt_id.to_i }
  end

  # None while the invitation to comment is out: the citizen's next step is writing,
  # and a support pill under "write your comment" is a way off the question.
  def buttons(conversation:)
    focus = ::Current.whatsapp_pill_focus

    return [] if focus.blank?
    return [] if conversation.comment_invited?

    if focus[:submission_completed]
      return submission_completed_buttons(conversation)
    end

    if focus[:proposal_id].present?
      return proposal_buttons(focus[:proposal_id], conversation)
    end

    projekt_buttons(focus[:projekt_id], conversation)
  end

  def submission_completed_buttons(conversation)
    SUBMISSION_COMPLETED_ACTIONS.filter_map do |action|
      pill(action: action, param: nil, conversation: conversation)
    end
  end

  def proposal_buttons(proposal_id, conversation)
    proposal = ::Proposal.not_retired.find_by(id: proposal_id)

    return [] if proposal.blank?

    [support_button(proposal, conversation), comment_button(proposal, conversation)].compact
  end

  def support_button(proposal, conversation)
    action = ::Whatsapp::AssistantActions.support_direction(proposal, conversation)

    return if action.blank?

    pill(action: action, param: proposal.id, conversation: conversation)
  end

  # Asked the way start_comment asks it, so the pill is offered exactly where a
  # comment would then be taken.
  def comment_button(proposal, conversation)
    refusal = ::Whatsapp::Contributions::CreateCommentService.thread_refusal(
      proposal: proposal, user: conversation.user
    )

    return if refusal.present?

    pill(action: :comment_start, param: proposal.id, conversation: conversation)
  end

  # Only for a linked number: following writes a subscription to the citizen's
  # account, and manage_subscription refuses an unlinked one for the same reason.
  def projekt_buttons(projekt_id, conversation)
    user = conversation.user
    projekt = ::Projekt.activated.find_by(id: projekt_id)

    return [] if user.blank? || projekt.blank?

    action =
      if ::Whatsapp::Subscriptions.following?(user: user, projekt: projekt)
        :follow_disable
      else
        :follow_enable
      end

    [pill(action: action, param: projekt.id, conversation: conversation)].compact
  end

  def pill(action:, param:, conversation:)
    title = ::Whatsapp::AssistantActions.truncated(
      ::Whatsapp::AssistantActions.forced_label(
        action: action, param: param, conversation: conversation
      )
    )

    return if title.blank?

    { id: ::Whatsapp::FlowActions.id_for(action: action, param: param), title: title }
  end

  private_class_method :submission_completed_buttons, :proposal_buttons, :support_button,
    :comment_button, :projekt_buttons, :pill
end
