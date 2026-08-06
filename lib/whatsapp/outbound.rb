module Whatsapp::Outbound
  # Every dead end offers a way out, so a citizen never has to guess what the
  # bot expects next. Ids are global: they are handled before the step
  # dispatcher, so a button works from whatever state the flow is in.
  RECOVERY_ACTION_IDS = {
    retry: "whatsapp_retry",
    cancel: "whatsapp_cancel",
    menu: "whatsapp_menu"
  }.freeze

  MAX_RECOVERY_BUTTONS = 3

  module_function

  def text(account:, body:)
    deliver_within_service_window(account: account, kind: "text", body: body) do |messages|
      messages.send_text(to: account.wa_id, body: body)
    end
  end

  def buttons(account:, body:, buttons:)
    deliver_within_service_window(account: account, kind: "interactive", body: body) do |messages|
      messages.send_buttons(to: account.wa_id, body: body, buttons: buttons)
    end
  end

  def list(account:, body:, button_label:, rows:)
    deliver_within_service_window(account: account, kind: "interactive", body: body) do |messages|
      messages.send_list(to: account.wa_id, body: body, button_label: button_label, rows: rows)
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
      body: "#{name}: #{variables.join(' | ')}",
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
      body: "#{name}: #{variables.join(' | ')}",
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

  def recovery(conversation:, body:, actions:)
    buttons(
      account: conversation.whatsapp_account,
      body: body,
      buttons: recovery_buttons(actions)
    )
  end

  def recovery_action_from(button_reply_id)
    RECOVERY_ACTION_IDS.key(button_reply_id.to_s)
  end

  def recovery_buttons(actions)
    actions.first(MAX_RECOVERY_BUTTONS).map do |action|
      { id: RECOVERY_ACTION_IDS.fetch(action), title: I18n.t("whatsapp.bot.buttons.#{action}") }
    end
  end

  def deliver_within_service_window(account:, kind:, body:, &block)
    return if !Whatsapp::ServiceWindow.deliverable?(account, kind)

    deliver(account: account, kind: kind, body: body, &block)
  end

  def deliver(account:, kind:, body:, projekt_id: nil)
    response = yield(WhatsappApi::Client.new.messages)

    WhatsappMessage.record_outbound!(
      account: account,
      kind: kind,
      body: body,
      projekt_id: projekt_id,
      response: response
    )
  end

  private_class_method :recovery_buttons, :deliver_within_service_window, :deliver
end
