module Whatsapp::NotificationFollowUp
  # The tappable half of a notification the bot sends on its own initiative.
  #
  # A notification is an approved template, and a template's buttons are approved
  # with it: adding one means a submission to Meta per portal, so a reminder that
  # wants to offer a way in cannot simply grow one. What it can do is say the same
  # thing in a second message — and only where WhatsApp allows a second message at
  # all, which is inside the twenty-four hours since the citizen last wrote. That
  # is exactly why `Whatsapp::Send.buttons` is the right call to make here without
  # asking first: outside the window it returns nil and nothing is sent, so the
  # window check and the send are one decision rather than two that can disagree.
  #
  # The labels are locale copy rather than a record's own name. A projekt title cut
  # to twenty characters is a worse button than "View project", and both pills on a
  # deadline reminder would otherwise read as the same projekt twice and one of them
  # would be dropped as a duplicate.
  #
  # Nothing here is offered that the tap cannot then do: a phase whose deadline has
  # passed is not offered a submission, and the ids are composed from records the
  # job has already loaded rather than from anything a model wrote.
  module_function

  # The reminder about a phase. `deadline_approaching` can still be acted on, so it
  # leads with taking part; `deadline_passed` cannot, and leads with looking.
  def phase_deadline(account:, projekt_phase:, kind:)
    projekt = projekt_phase.projekt

    return if projekt.blank?

    send_offer(
      account: account,
      body: I18n.t("whatsapp.bot.notifications.follow_up.#{kind}"),
      pills: pills_for(kind, projekt_phase: projekt_phase, projekt: projekt)
    )
  end

  # The push about the citizen's own proposal. Their own contributions is the
  # honest second step: what changed on it is visible from there, and it is the one
  # list this citizen is certain to have a row in.
  def proposal_status(account:, proposal:)
    projekt = proposal.projekt_phase&.projekt

    return if projekt.blank?

    send_offer(
      account: account,
      body: I18n.t("whatsapp.bot.notifications.follow_up.status_change"),
      pills: [
        pill(:my_contributions, label: "my_contributions"),
        pill(:view_projekt, param: projekt.id, label: "view_projekt")
      ]
    )
  end

  def pills_for(kind, projekt_phase:, projekt:)
    return [
      pill(:view_projekt, param: projekt.id, label: "view_projekt"),
      pill(:my_contributions, label: "my_contributions")
    ] if kind.to_s == "deadline_passed"

    [
      pill(:idea_start, param: projekt_phase.id, label: "take_part"),
      pill(:view_projekt, param: projekt.id, label: "view_projekt")
    ]
  end

  def pill(action, label:, param: nil)
    {
      id: ::Whatsapp::FlowActions.id_for(action: action, param: param),
      title: I18n.t("whatsapp.bot.buttons.#{label}")
    }
  end

  # The body and the labels under it travel through one translation call, for the
  # reason BotCopyService gives: translated apart they drift into two registers,
  # and here they are also the only lines of the exchange the citizen did not
  # prompt. What fits in a button is a property of the translated label rather than
  # of the copy it was written from, so the fit is decided after the translation —
  # and a translation that can only arrive cut mid-word gives way to the written
  # copy, which is what fitting_label is for.
  def send_offer(account:, body:, pills:)
    lines = ::Whatsapp::AiAssistant::BotCopyService.call(
      account: account, lines: [body, *pills.map { |pill| pill[:title] }]
    )

    ::Whatsapp::Send.buttons(
      account: account,
      body: lines.first,
      buttons: pills.zip(lines.drop(1)).map do |pill, title|
        pill.merge(
          title: ::Whatsapp::AssistantActions.fitting_label(
            translated: title, original: pill[:title]
          )
        )
      end
    )
  end
end
