module Whatsapp::Send
  # Every dead end offers a way out, so a citizen never has to guess what the
  # bot expects next. Ids are global: they are handled before the step
  # dispatcher, so a button works from whatever state the flow is in.
  # `help` replaced `menu` when the portal-wide list menu was archived: the
  # catalog's way out of a dead end is the help overview, and a button that
  # opened a menu which no longer exists would be the dead end itself.
  RECOVERY_ACTION_IDS = {
    retry: "whatsapp_retry",
    cancel: "whatsapp_cancel",
    help: "whatsapp_help"
  }.freeze

  MAX_RECOVERY_BUTTONS = ::Whatsapp::MAX_BUTTONS

  module_function

  def text(account:, body:)
    deliver_within_service_window(account: account, kind: "text", body: body) do |messages|
      messages.send_text(to: account.wa_id, body: body)
    end
  end

  # The bot's own locale copy, put into the citizen's language on its way out. Only
  # ever for the fixed lines: what the assistant writes is already in the language it
  # was asked to answer in, and a round trip through a second model could only lose
  # it.
  def locale_text(account:, body:)
    text(
      account: account,
      body: ::Whatsapp::AiAssistant::BotCopyService.line(account: account, body: body)
    )
  end

  def buttons(account:, body:, buttons:, header_image_url: nil)
    message = deliver_within_service_window(
      account: account, kind: "interactive", body: body
    ) do |messages|
      messages.send_buttons(
        to: account.wa_id,
        body: body,
        buttons: buttons,
        header_image_url: header_image_url
      )
    end

    remember_confirmations(account: account, entries: buttons, message: message)
  end

  # For a picture that exists only on an unpublished record. Uploading it to
  # WhatsApp first means nothing about the send depends on Meta being able to
  # reach us, which on an access-restricted environment it cannot.
  def buttons_with_media_header(account:, body:, buttons:, header_media_id:)
    message = deliver_within_service_window(
      account: account, kind: "interactive", body: body
    ) do |messages|
      messages.send_buttons_with_media_header(
        to: account.wa_id,
        body: body,
        buttons: buttons,
        header_media_id: header_media_id
      )
    end

    remember_confirmations(account: account, entries: buttons, message: message)
  end

  # A message that carries a picture, and what to do when WhatsApp will not take
  # it. Which route works is a property of the transport rather than of the flow
  # asking, so the ladder is walked here: the media id first, because an
  # uploaded picture travels with the send and needs nothing fetched from us;
  # the blob URL second, which WhatsApp fetches mid-send and which it refuses
  # the whole message over when our host is not reachable from its network — an
  # access-restricted environment, every time.
  #
  # A refused send is repeated without the picture rather than left undelivered:
  # the citizen is standing at a step that expects an answer, and no message at
  # all is the one outcome worse than a message they cannot see the photo in.
  # Nil for both routes is simply the message, which is what the caller wants
  # when there was no showable picture to begin with.
  def buttons_with_picture(account:, body:, buttons:, media_id: nil, image_url: nil)
    return buttons_with_media_header(
      account: account, body: body, buttons: buttons, header_media_id: media_id
    ) if media_id.present?

    return buttons(account: account, body: body, buttons: buttons) if image_url.blank?

    message = buttons(account: account, body: body, buttons: buttons, header_image_url: image_url)

    return message if message&.status != "failed"

    Rails.logger.info("[Whatsapp] picture header refused, message re-sent without it")

    buttons(account: account, body: body, buttons: buttons)
  end

  # The caption is recorded as the message body: the dialog history in /adm is
  # read to find out what the bot said, and "image" alone answers nothing.
  def image(account:, image_url:, caption: nil)
    deliver_within_service_window(account: account, kind: "image", body: caption.to_s) do |messages|
      messages.send_image(to: account.wa_id, image_url: image_url, caption: caption)
    end
  end

  def list(account:, body:, button_label:, rows:)
    message = deliver_within_service_window(
      account: account, kind: "interactive", body: body
    ) do |messages|
      messages.send_list(to: account.wa_id, body: body, button_label: button_label, rows: rows)
    end

    remember_confirmations(account: account, entries: rows, message: message)
  end

  # For a list long enough that ungrouped rows read as a wall. Sections are
  # {title:, rows:}; the ten-row limit is shared across all of them.
  def sectioned_list(account:, body:, button_label:, sections:)
    message = deliver_within_service_window(
      account: account, kind: "interactive", body: body
    ) do |messages|
      messages.send_sectioned_list(
        to: account.wa_id, body: body, button_label: button_label, sections: sections
      )
    end

    remember_confirmations(
      account: account,
      entries: Array(sections).flat_map { |section| Array(section[:rows]) },
      message: message
    )
  end

  # The native location picker. Recorded as an interactive message like every
  # other tappable one, so the dialog history in /adm reads in order.
  def location_request(account:, body:)
    deliver_within_service_window(account: account, kind: "interactive", body: body) do |messages|
      messages.send_location_request(to: account.wa_id, body: body)
    end
  end

  def cta_url(account:, body:, button_label:, url:)
    deliver_within_service_window(account: account, kind: "interactive", body: body) do |messages|
      messages.send_cta_url(to: account.wa_id, body: body, button_label: button_label, url: url)
    end
  end

  # No service-window guard: an approved template is the only thing WhatsApp
  # accepts once the 24-hour window has closed, which is the whole reason to
  # send one.
  def template(account:, name:, variables: [], language: nil, projekt_id: nil)
    language ||= ::Whatsapp.broadcast_template_language

    deliver(
      account: account,
      kind: "template",
      body: "#{name}: #{variables.join(" | ")}",
      projekt_id: projekt_id
    ) do |messages|
      messages.send_template(to: account.wa_id, name: name, language: language, variables: variables)
    end
  end

  # The projekt card: same no-guard reasoning as `template`, plus an image the
  # recipient's phone fetches from us and a button variable the template appends
  # to its own fixed URL prefix.
  def card_template(
    account:, name:, image_url:, variables:, button_variable:, language: nil, projekt_id: nil
  )
    language ||= ::Whatsapp.broadcast_template_language

    deliver(
      account: account,
      kind: "template",
      body: "#{name}: #{variables.join(" | ")}",
      projekt_id: projekt_id
    ) do |messages|
      messages.send_card_template(
        to: account.wa_id,
        name: name,
        language: language,
        image_url: image_url,
        variables: variables,
        button_variable: button_variable
      )
    end
  end

  # The same shape when the way out is a retry or a cancel rather than a pill of the
  # bot's own. It is the whole deterministic surface left: everything else the
  # citizen reads is written by the assistant, and this is what speaks when the
  # assistant cannot.
  #
  # The sentence and the labels under it are put into the citizen's language in one
  # call rather than three, so a body and its buttons can never come back in two
  # different ones.
  def recovery(conversation:, body:, actions:)
    pills = recovery_buttons(actions)
    lines = ::Whatsapp::AiAssistant::BotCopyService.call(
      account: conversation.whatsapp_account,
      lines: [body, *pills.map { |pill| pill[:title] }]
    )

    buttons(
      account: conversation.whatsapp_account,
      body: lines.first,
      buttons: pills.zip(lines.drop(1)).map { |pill, title| pill.merge(title: title) }
    )
  end

  # The one message that cannot be put into the citizen's language, because it is sent
  # precisely when the assistant did not answer: asking the same provider to translate
  # it would spend a second timeout on the reply that exists to survive the first one.
  # It goes out in the portal's own language, which is the point of there being fixed
  # copy at all.
  def recovery_without_assistant(conversation:, body:, actions:)
    buttons(
      account: conversation.whatsapp_account, body: body, buttons: recovery_buttons(actions)
    )
  end

  def recovery_action_from(button_reply_id)
    RECOVERY_ACTION_IDS.key(button_reply_id.to_s)
  end

  # One recovery pill on its own, for the deterministic messages that offer a way
  # out. Its label is locale copy rather than the assistant's, which is the whole
  # point of the recovery namespace: these are the buttons that have to be readable
  # when nothing else is.
  def recovery_button(action)
    { id: RECOVERY_ACTION_IDS.fetch(action), title: I18n.t("whatsapp.bot.buttons.#{action}") }
  end

  def recovery_buttons(actions)
    actions.first(MAX_RECOVERY_BUTTONS).map { |action| recovery_button(action) }
  end

  # WhatsApp dismisses the bubble after this long, and there is no way to extend
  # it — the indicator belongs to one inbound message. A turn that can outrun it
  # is a turn worth making faster rather than one worth re-signalling.
  TYPING_INDICATOR_SECONDS = 25

  # Shown only on the turns that make the citizen wait: an LLM call, a draft, a
  # criteria evaluation. Deliberately not routed through `deliver` — this is not
  # a message, so it gets no whatsapp_messages row and never appears in the
  # dialog history the admin pages read.
  #
  # Never raises. The bubble is cosmetic: someone who does not see it waits
  # exactly as long, whereas an exception here would cost them the reply itself.
  def typing(message_id:)
    return if message_id.blank?

    WhatsappApi::Client.new.messages.send_typing_indicator(message_id: message_id)
  rescue StandardError => e
    Rails.logger.info("[Whatsapp] typing indicator failed: #{e.class} - #{e.message}")

    nil
  end

  # Which of an interactive message's buttons offered something that cannot be taken
  # back — publishing, registering support, severing the account link. Written onto
  # the conversation for every interactive send, so the tools that must not act
  # without having asked first can tell whether they asked: an assistant is
  # perfectly capable of deciding it has already confirmed something it never
  # mentioned.
  #
  # Overwritten rather than appended, which is the point: it names what the bot's
  # last message put in front of the citizen. A pill from four messages ago is a tap
  # they can still make — the dispatcher re-resolves it — but not a confirmation the
  # assistant may infer from words.
  #
  # A send that never happened offers nothing: outside the service window
  # `deliver_within_service_window` returns nil, and a refused send comes back as a
  # failed message. Either way the previous offer stands, because the citizen's
  # screen still shows it.
  def remember_confirmations(account:, entries:, message:)
    return message if message.blank? || message.status == "failed"

    conversation = account.conversation

    return message if conversation.blank?

    conversation.remember_confirmations!(irreversible_ids(entries))

    message
  end

  def irreversible_ids(entries)
    Array(entries).filter_map do |entry|
      action = ::Whatsapp::FlowActions.parse(entry[:id])&.fetch(:action)

      next if action.blank?
      next if !::Whatsapp::AssistantActions::IRREVERSIBLE_ACTIONS.include?(action)

      action.to_s
    end
  end

  def deliver_within_service_window(account:, kind:, body:, &block)
    return if !Whatsapp::ServiceWindow.deliverable?(account, kind)

    deliver(account: account, kind: kind, body: body, &block)
  end

  def deliver(account:, kind:, body:, projekt_id: nil)
    response = yield(WhatsappApi::Client.new.messages)

    Whatsapp::Message.record_outbound!(
      account: account,
      kind: kind,
      body: body,
      projekt_id: projekt_id,
      response: response
    )
  end

  private_class_method :recovery_buttons, :deliver_within_service_window, :deliver
  private_class_method :remember_confirmations, :irreversible_ids
end
