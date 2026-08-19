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

    remember_offered(account: account, entries: buttons, message: message)
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

    remember_offered(account: account, entries: buttons, message: message)
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

    remember_offered(account: account, entries: rows, message: message)
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

    remember_offered(
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

  # Recorded on the conversation as well as sent: these buttons are the bot
  # asking something, and "abbrechen" typed instead of tapping Cancel has to be
  # read as cancelling that question rather than as the opt-out keyword. The step
  # cannot answer that on its own — the assistant sends these while the
  # conversation is still idle. Whatsapp::Message carries no marker to read
  # instead: recovery buttons, projekt cards and lists are all "interactive".
  #
  # Every asking message goes through here, whatever its buttons are, so the
  # flag is written in exactly one place. A second copy of this pairing is how
  # a future asker ends up sending one without it.
  def question(conversation:, body:, buttons:)
    conversation.mark_question_pending!

    ::Whatsapp::Send.buttons(
      account: conversation.whatsapp_account, body: body, buttons: buttons
    )
  end

  # The same question when its way out is a retry or a cancel rather than one of
  # the flow's own pills.
  def recovery(conversation:, body:, actions:)
    question(conversation: conversation, body: body, buttons: recovery_buttons(actions))
  end

  def recovery_action_from(button_reply_id)
    RECOVERY_ACTION_IDS.key(button_reply_id.to_s)
  end

  # One recovery pill to put beside flow buttons of a different kind. The
  # handler is the same global one either way, which is the point: a "Cancel"
  # sitting next to two catalog pills must not need its own step to be read.
  #
  # Unlike `recovery`, this sets no pending_question: the callers that use it
  # are already on a step of their own, so "abbrechen" typed instead of tapped
  # is read by the step rather than by the flag.
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

  # How many of an interactive message's options are remembered as answerable
  # in words. Ten is the list cap, so this only ever bites a sectioned list
  # built past it — and there the first ten are the ones the citizen read.
  MAX_REMEMBERED_OPTIONS = ::Whatsapp::MAX_LIST_ROWS

  # Every tappable option the bot sends is also written onto the conversation,
  # so the assistant can be told what is on offer and a citizen who answers in
  # words — "die zweite", "ja, trennen", "eher Kritik" — is understood instead
  # of being re-asked the same question. The pill's own dispatcher still does
  # the work: an id named back by the model travels the identical path a tap
  # would have, account gating and record re-resolution included.
  #
  # Written here rather than by each step because here is where the options
  # exist: one hook covers the whole catalog, every menu, and every step
  # written from now on. Only ids the inbound side can actually dispatch are
  # kept — a row whose id belongs to neither namespace (there are none today)
  # would otherwise be offered to the model as an answer nothing would accept.
  #
  # A send that never happened offers nothing: outside the service window
  # `deliver_within_service_window` returns nil, and a refused send comes back
  # as a failed message. Either way the previous options stand, because the
  # citizen's screen still shows them.
  def remember_offered(account:, entries:, message:)
    return message if message.blank? || message.status == "failed"

    conversation = account.conversation

    return message if conversation.blank?

    conversation.remember_offered_options!(dispatchable_options(entries))

    message
  end

  def dispatchable_options(entries)
    Array(entries)
      .select { |entry| dispatchable_id?(entry[:id]) }
      .first(MAX_REMEMBERED_OPTIONS)
      .map { |entry| { "id" => entry[:id].to_s, "label" => entry[:title].to_s } }
  end

  def dispatchable_id?(reply_id)
    return false if reply_id.blank?
    return true if recovery_action_from(reply_id).present?

    ::Whatsapp::FlowActions.parse(reply_id).present?
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
  private_class_method :remember_offered, :dispatchable_options, :dispatchable_id?
end
