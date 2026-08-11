module Whatsapp::Outbound
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
    deliver_within_service_window(account: account, kind: "interactive", body: body) do |messages|
      messages.send_buttons(
        to: account.wa_id,
        body: body,
        buttons: buttons,
        header_image_url: header_image_url
      )
    end
  end

  # For a picture that exists only on an unpublished record. Uploading it to
  # WhatsApp first means nothing about the send depends on Meta being able to
  # reach us, which on an access-restricted environment it cannot.
  def buttons_with_media_header(account:, body:, buttons:, header_media_id:)
    deliver_within_service_window(account: account, kind: "interactive", body: body) do |messages|
      messages.send_buttons_with_media_header(
        to: account.wa_id,
        body: body,
        buttons: buttons,
        header_media_id: header_media_id
      )
    end
  end

  # The caption is recorded as the message body: the dialog history in /adm is
  # read to find out what the bot said, and "image" alone answers nothing.
  def image(account:, image_url:, caption: nil)
    deliver_within_service_window(account: account, kind: "image", body: caption.to_s) do |messages|
      messages.send_image(to: account.wa_id, image_url: image_url, caption: caption)
    end
  end

  def list(account:, body:, button_label:, rows:)
    deliver_within_service_window(account: account, kind: "interactive", body: body) do |messages|
      messages.send_list(to: account.wa_id, body: body, button_label: button_label, rows: rows)
    end
  end

  # For a list long enough that ungrouped rows read as a wall. Sections are
  # {title:, rows:}; the ten-row limit is shared across all of them.
  def sectioned_list(account:, body:, button_label:, sections:)
    deliver_within_service_window(account: account, kind: "interactive", body: body) do |messages|
      messages.send_sectioned_list(
        to: account.wa_id, body: body, button_label: button_label, sections: sections
      )
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
  def recovery(conversation:, body:, actions:)
    conversation.merge_context!(pending_question: true)

    buttons(
      account: conversation.whatsapp_account,
      body: body,
      buttons: recovery_buttons(actions)
    )
  end

  # Like `recovery`, for a message whose way out is one of the flow's own pills
  # rather than a retry — so the buttons come from the caller instead of from
  # the recovery list. The flag is set for the same reason and must not be left
  # to the caller: without it, "abbrechen" typed instead of tapped is read as
  # the opt-out keyword rather than as an answer to what was just asked, and
  # nothing about the message says so.
  def question(conversation:, body:, buttons:)
    conversation.merge_context!(pending_question: true)

    ::Whatsapp::Outbound.buttons(
      account: conversation.whatsapp_account, body: body, buttons: buttons
    )
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
end
