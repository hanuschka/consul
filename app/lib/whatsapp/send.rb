module Whatsapp::Send
  # Every dead end offers a way out, so a citizen never has to guess what the
  # bot expects next. Ids are global: they are handled before the step
  # dispatcher, so a button works from whatever state the flow is in.
  # `help` replaced `menu` when the portal-wide list menu was archived: the
  # catalog's way out of a dead end is the help overview, and a button that
  # opened a menu which no longer exists would be the dead end itself.
  # `retry` and `link_retry` are two different offers wearing one word. The first
  # replays the turn the assistant could not answer, which the inbound chain does
  # from a snapshot it holds; the second asks the citizen to follow their login
  # link again, which no snapshot has anything to do with. One id for both had a
  # tap on the link pill answered with whatever turn had last failed.
  RECOVERY_ACTION_IDS = {
    retry: "whatsapp_retry",
    link_retry: "whatsapp_link_retry",
    cancel: "whatsapp_cancel",
    help: "whatsapp_help"
  }.freeze

  # The reservation applies here too: with_main_menu trims past it, so building
  # three recovery pills would silently lose the last one.
  MAX_RECOVERY_BUTTONS = ::Whatsapp::MAX_OFFERED_BUTTONS

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
    offered = with_main_menu(account: account, buttons: buttons)
    message = deliver_buttons(
      account: account, body: body, offered: offered, header_image_url: header_image_url
    )

    remember_confirmations(account: account, entries: offered, message: message)
  end

  # The same send without the confirmation record, for the recovery lines. Their
  # pills are locale copy from a fixed list and never irreversible, so there is
  # nothing here to remember — but going through `buttons` would still overwrite
  # what the previous message offered with an empty list, and the citizen's screen
  # still shows that message. A "could not answer" line under a comment awaiting a
  # yes would have thrown the yes away.
  def recovery_buttons_message(account:, body:, buttons:)
    deliver_buttons(
      account: account,
      body: body,
      offered: with_main_menu(account: account, buttons: buttons),
      header_image_url: nil
    )
  end

  def deliver_buttons(account:, body:, offered:, header_image_url:)
    deliver_within_service_window(
      account: account, kind: "interactive", body: body
    ) do |messages|
      messages.send_buttons(
        to: account.wa_id,
        body: body,
        buttons: offered,
        header_image_url: header_image_url
      )
    end
  end

  # For a picture that exists only on an unpublished record. Uploading it to
  # WhatsApp first means nothing about the send depends on Meta being able to
  # reach us, which on an access-restricted environment it cannot.
  def buttons_with_media_header(account:, body:, buttons:, header_media_id:)
    offered = with_main_menu(account: account, buttons: buttons)

    message = deliver_within_service_window(
      account: account, kind: "interactive", body: body
    ) do |messages|
      messages.send_buttons_with_media_header(
        to: account.wa_id,
        body: body,
        buttons: offered,
        header_media_id: header_media_id
      )
    end

    remember_confirmations(account: account, entries: offered, message: message)
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

  def image_from_media(account:, media_id:, caption: nil)
    deliver_within_service_window(account: account, kind: "image", body: caption.to_s) do |messages|
      messages.send_image_by_media_id(to: account.wa_id, media_id: media_id, caption: caption)
    end
  end

  # A captioned picture and what to do when WhatsApp will not take it — the same
  # ladder buttons_with_picture walks, and for the same reasons: the uploaded media
  # id first because it travels with the send, the blob URL second because WhatsApp
  # has to fetch it from a host its network may not reach.
  #
  # Nil when neither route arrived, which is the caller's signal to say the same
  # thing in text. Unlike the button card there is nothing to re-send without the
  # picture: a picture message without its picture is not a message.
  def picture(account:, media_id: nil, image_url: nil, caption: nil)
    uploaded =
      if media_id.present?
        image_from_media(account: account, media_id: media_id, caption: caption)
      end

    return uploaded if delivered?(uploaded)
    return if image_url.blank?

    fetched = image(account: account, image_url: image_url, caption: caption)

    return fetched if delivered?(fetched)

    Rails.logger.info("[Whatsapp] picture refused by both routes, nothing sent")

    nil
  end

  def delivered?(message)
    message.present? && message.status != "failed"
  end

  def list(account:, body:, button_label:, rows:)
    listed = with_main_menu_row(account: account, rows: rows)

    message = deliver_within_service_window(
      account: account, kind: "interactive", body: body
    ) do |messages|
      messages.send_list(to: account.wa_id, body: body, button_label: button_label, rows: listed)
    end

    remember_confirmations(account: account, entries: listed, message: message)
  end

  # For a list long enough that ungrouped rows read as a wall. Sections are
  # {title:, rows:}; the ten-row limit is shared across all of them.
  def sectioned_list(account:, body:, button_label:, sections:)
    listed = with_main_menu_section(account: account, sections: sections)

    message = deliver_within_service_window(
      account: account, kind: "interactive", body: body
    ) do |messages|
      messages.send_sectioned_list(
        to: account.wa_id, body: body, button_label: button_label, sections: listed
      )
    end

    remember_confirmations(
      account: account,
      entries: Array(listed).flat_map { |section| Array(section[:rows]) },
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

    recovery_buttons_message(
      account: conversation.whatsapp_account,
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

  # The one message that cannot be put into the citizen's language, because it is sent
  # precisely when the assistant did not answer: asking the same provider to translate
  # it would spend a second timeout on the reply that exists to survive the first one.
  # It goes out in the portal's own language, which is the point of there being fixed
  # copy at all.
  def recovery_without_assistant(conversation:, body:, actions:)
    recovery_buttons_message(
      account: conversation.whatsapp_account, body: body, buttons: recovery_buttons(actions)
    )
  end

  # ── The main-menu pill every interactive message carries ────────────────
  # Injected here rather than at each caller, and that is the whole point: "every
  # reply has a way out of it" is a property of the transport, so a tool added next
  # month inherits it without knowing it exists. Nine callers each remembering to
  # append one is nine chances for the one message a citizen is stuck on to be the
  # one that forgot.
  #
  # It costs the last slot, so a caller may fill only MAX_OFFERED_BUTTONS of the
  # three — trimming its list here instead would drop whichever pill it thought
  # least important without saying so. The trim below is the backstop for a caller
  # that ignores the cap, and it keeps the caller's own pills: the menu is the least
  # of what a message offers, so it is what gives way when there is no room.
  #
  # The label is read at the account's own locale rather than translated through
  # BotCopyService. Two reasons: this runs on the path that must survive the model
  # being unreachable, and it is one fixed word — a citizen writing a language the
  # portal has no copy for reads the menu pill in the portal's language and every
  # other line of the message in their own, which is the cheap half of the trade.
  def with_main_menu(account:, buttons:)
    offered = Array(buttons).compact

    return offered if offered.any? { |button| main_menu_button?(button) }

    offered.first(::Whatsapp::MAX_OFFERED_BUTTONS) + [main_menu_pill(account)]
  end

  def with_main_menu_row(account:, rows:)
    listed = Array(rows).compact

    return listed if listed.any? { |row| main_menu_button?(row) }

    listed.first(::Whatsapp::MAX_OFFERED_LIST_ROWS) + [main_menu_pill(account)]
  end

  # A section of its own rather than a row appended to the last one: the sections
  # carry titles saying what their rows have in common, and the way out belongs to
  # none of them. Titled, because WhatsApp requires a title on every section of a
  # multi-section list and rejects the whole message without one — and the protocol
  # edge drops a blank title rather than refusing, so an untitled section here would
  # have failed as the entire list.
  def with_main_menu_section(account:, sections:)
    listed = Array(sections).compact
    rows = listed.flat_map { |section| Array(section[:rows]) }

    return listed if rows.any? { |row| main_menu_button?(row) }

    menu = main_menu_pill(account)

    trimmed_sections(listed) + [{ title: menu[:title], rows: [menu] }]
  end

  # Trimmed from the end, one row at a time, because the ten-row cap is shared
  # across every section and the last section is the least prominent.
  def trimmed_sections(sections)
    rows = sections.sum { |section| Array(section[:rows]).size }

    return sections if rows <= ::Whatsapp::MAX_OFFERED_LIST_ROWS

    over = rows - ::Whatsapp::MAX_OFFERED_LIST_ROWS

    sections.reverse.map do |section|
      kept = Array(section[:rows])
      dropping = [over, kept.size].min
      over -= dropping

      section.merge(rows: kept.first(kept.size - dropping))
    end.reverse.reject { |section| Array(section[:rows]).empty? }
  end

  def main_menu_pill(account)
    {
      id: ::Whatsapp::FlowActions.id_for(action: :main_menu),
      title: I18n.t(
        "whatsapp.bot.buttons.main_menu", locale: ::Whatsapp.locale_for(account)
      )
    }
  end

  # Matched on the id rather than the label, because a caller that offered the menu
  # in the model's own words must not have a second one stacked under it.
  def main_menu_button?(button)
    button.is_a?(Hash) &&
      button[:id].to_s == ::Whatsapp::FlowActions.id_for(action: :main_menu)
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
  # it — the indicator belongs to one inbound message. A turn that outruns it
  # asks for it again rather than going quiet, which is what the tool loop does
  # on every call it makes.
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

  # The record the irreversible tools read back to answer "did we actually ask
  # them this". A parameterised action keeps its parameter, because for those the
  # question is not whether the bot asked but *what about*: "support" recorded
  # bare is satisfied by an offer for any proposal, so a pill shown for one and a
  # tool called with another looked identical from here.
  def irreversible_ids(entries)
    Array(entries).filter_map do |entry|
      parsed = ::Whatsapp::FlowActions.parse(entry[:id])
      action = parsed&.fetch(:action)

      next if action.blank?
      next if !::Whatsapp::AssistantActions::IRREVERSIBLE_ACTIONS.include?(action)

      [action, parsed[:param]].compact_blank.join(::Whatsapp::FlowActions::SEPARATOR)
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
  private_class_method :with_main_menu, :with_main_menu_row, :with_main_menu_section
  private_class_method :trimmed_sections, :main_menu_pill, :main_menu_button?
  private_class_method :deliver_buttons, :remember_confirmations, :irreversible_ids, :delivered?
end
