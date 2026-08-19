class Whatsapp::Inbound::TapDispatch
  # What happens when the citizen taps a button rather than typing. It replaces two
  # dispatchers and a step map, and the reason it is this small is that a tap is now
  # almost never an effect: the reply to it is the assistant's, so the tap is best
  # understood as a sentence the citizen did not have to type.
  #
  # Two things it still owes, and both are about the ids:
  #
  # A tapped id is checked against the vocabulary before anything acts on it. That
  # is what keeps a label the model invented from being tappable — WhatsApp returns
  # the *id*, so an id nothing knows is a tap that silently does nothing.
  #
  # Recovery ids are read before catalog ids, and they are the only ones with a
  # deterministic effect. That ordering is the contract: the two namespaces are built
  # by different modules from different prefixes, so reading recovery first can never
  # swallow a catalog pill — and cancelling has to work when the assistant does not,
  # which is the whole reason that namespace exists.
  #
  # Returns nil when the tap is not one of ours, :handled when it has been answered
  # in full, and otherwise a note for the assistant saying what was tapped and what
  # to do about it.
  def initialize(conversation:, reading:)
    @conversation = conversation
    @reading = reading
  end

  def call
    tapped_id = @reading.tapped_reply_id

    return if tapped_id.blank?

    recovery = ::Whatsapp::Send.recovery_action_from(tapped_id)

    return recovery_note(recovery) if recovery.present?

    catalog_note(tapped_id)
  end

  private

    # Cancelling is the one tap that does its own work. Everything else the citizen
    # reads comes from a model, so a tap that needs one is no worse off waiting for
    # it — but abandoning a submission must not depend on a provider being reachable,
    # for the same reason the typed stop keyword does not.
    def recovery_note(action)
      return cancel if action == :cancel

      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :tap_dispatched, conversation: @conversation, action: action
      )

      RECOVERY_NOTES.fetch(action)
    end

    def cancel
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :tap_dispatched, conversation: @conversation, action: :cancel
      )

      @conversation.discard_draft!

      ::Whatsapp::Send.text(
        account: @conversation.whatsapp_account,
        body: I18n.t("whatsapp.bot.cancelled")
      )

      :handled
    end

    RECOVERY_NOTES = {
      retry: "The citizen tapped the button offering to try again. Do whatever last failed, " \
             "once. If you cannot tell what that was, ask them.",
      help: "The citizen tapped the help button. Read what is actually open and tell them what " \
            "they can do here right now, naming it — not a standing list of capabilities."
    }.freeze

    def catalog_note(tapped_id)
      flow_action = ::Whatsapp::FlowActions.parse(tapped_id)

      return unhandled_note(tapped_id) if flow_action.blank?

      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :tap_dispatched, conversation: @conversation,
        action: flow_action[:action], param: flow_action[:param]
      )

      [tapped_line(flow_action), instruction_for(flow_action)].compact.join(" ")
    end

    # The label the citizen actually read, taken from the webhook rather than from
    # anything remembered here: WhatsApp sends back the title beside the id, and the
    # assistant wrote that title in the first place, so quoting it is how the note
    # says what the citizen thinks they just asked for.
    def tapped_line(flow_action)
      label = @reading.tapped_reply_title.to_s.squish
      named = label.present? ? " labelled \"#{label}\"" : ""
      param = flow_action[:param].present? ? ", id #{flow_action[:param]}" : ""

      "The citizen tapped the button#{named} (action #{flow_action[:action]}#{param})."
    end

    def instruction_for(flow_action)
      instruction = INSTRUCTIONS[flow_action[:action]]

      return generic_instruction if instruction.blank?

      sprintf(instruction, param: flow_action[:param])
    end

    def generic_instruction
      "Work out from the label what they are asking for and answer it."
    end

    # One line per action saying what the tap means, because the label alone does not
    # say it: the assistant wrote that label a message ago and is reading this turn
    # fresh, and "Ja, einreichen" beside a draft and beside an unlink question mean
    # very different things.
    #
    # Where an id travels with the tap it is spelled into the instruction, so the
    # model passes back the id the citizen really chose rather than one it remembers.
    # Nothing here performs the action: the tool does, and it re-resolves the record
    # and re-checks the phase on the way — which is what stops a pill tapped a week
    # later from acting on something that has moved on.
    INSTRUCTIONS = {
      main_menu: "They want to start again from the top. Read what is open and tell them what " \
                 "there is to do right now.",
      participate: "They want to take part in something. Read what is open and let them choose.",
      participate_projekt: "They chose projekt %{param}. Tell them what can be done in it right " \
                           "now and let them choose.",
      submit_proposal: "They want to contribute something. Read which phases are open for " \
                       "contributions and let them choose one, then start_draft.",
      idea_start: "They want to contribute to phase %{param}. Call start_draft with that id, " \
                  "then ask them what they want to contribute.",
      discover: "They want to see what the portal is running. Read it and tell them.",
      discover_category: "They want to see more of the \"%{param}\" projekts. Read them and tell " \
                         "them.",
      discover_public: "They want to see what is running without linking an account. Read it " \
                       "and tell them.",
      view_projekt: "They want to know about projekt %{param}. Describe it and send its card.",
      my_contributions: "They want to see what they have submitted. Read it and tell them.",
      notifications_open: "They want to change which messages they get. Read their settings and " \
                          "offer the switches.",
      notifications_done: "They are finished with their notification settings. Confirm in one " \
                          "line and stop.",
      unlink_start: "They are asking to unlink this number from their account. Tell them what " \
                    "that loses and offer the unlink_confirm button — do not unlink yet.",
      unlink_cancel: "They decided against unlinking. Say plainly that nothing was changed and " \
                     "that the account is still connected.",
      unlink_confirm: "They have confirmed the unlink after being asked. Call unlink_account.",
      dismiss: "They declined what was offered. Say plainly that nothing happened and leave it " \
               "there — do not offer them something else instead.",
      terms_accept: "They accept the terms and the privacy policy. Call record_terms_consent, " \
                    "then carry on with what they were doing.",
      terms_decline: "They will not accept the terms. Say in one line that nothing can be " \
                     "submitted without them, and do not ask again in this conversation.",
      draft_publish: "They confirm the draft should go in as it stands. Call publish_draft.",
      submit_final: "They confirm the draft should go in as it stands. Call publish_draft.",
      draft_revise: "They want the draft changed. Ask what should be different, unless they have " \
                    "already said, and then call revise_draft.",
      submit_anyway: "They want to submit their own contribution rather than support one that " \
                     "already exists. Go on with their draft and do not raise the duplicate " \
                     "again.",
      support: "They confirm they want to support contribution %{param}. Call support_proposal " \
               "with that id.",
      support_prompt: "They want to support a contribution but have not said which. Ask them " \
                      "which one, then find_contribution.",
      comment_prompt: "They want to comment on a contribution. Ask which one and what they want " \
                      "to say, then find_contribution and comment_on_proposal.",
      category: "They chose category %{param} for their draft. Call set_draft_category with it.",
      sentiment: "They chose sentiment %{param} for their draft. Call set_draft_sentiment with " \
                 "it.",
      image_upload: "They want to send a photo of their own. Ask them to send it and remind them " \
                    "they must hold its rights; attach_draft_image once it arrives.",
      image_generate: "They want the portal to make a picture for their draft. Tell them it is " \
                      "being made, then call generate_draft_image.",
      image_skip: "They want no picture. Do not ask about one again — go on to whatever is left.",
      location_share: "They are willing to drop a pin. Call request_location.",
      location_skip: "They will not give a pin. Do not ask again — go on to publishing.",
      notify_toggle: "They want to switch notification \"%{param}\". Call toggle_notification " \
                     "with it.",
      link_yes: "They want to link their account. Call send_login_link.",
      link_later: "They would rather not link an account now. Say what they can still do without " \
                  "one, and do not ask again in this conversation.",
      link_retry: "They want the login link again. Call send_login_link."
    }.freeze

    # A pill from an older deploy, still sitting in someone's chat history and still
    # tappable forever. Answered rather than dropped: a tap that produces nothing at
    # all reads as a bot that has stopped working, and the citizen taps again.
    def unhandled_note(tapped_id)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :tap_unhandled, conversation: @conversation, tapped: tapped_id
      )

      label = @reading.tapped_reply_title.to_s.squish

      return generic_unhandled_note if label.blank?

      "The citizen tapped an old button labelled \"#{label}\", which no longer does anything. " \
        "Work out from the label what they want and answer that, without mentioning the button."
    end

    def generic_unhandled_note
      "The citizen tapped a button from an earlier conversation that no longer does anything, " \
        "and nothing about it says what they wanted. Ask them what they would like to do."
    end
end
