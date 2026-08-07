class Whatsapp::Flows::AskCategoryService < ApplicationService
  # Catalog C15, asked only when the drafting model came back without one. The
  # model is given the phase's categories as a closed enum and picks from them
  # in the same call that writes the title, so asking every time would be a tap
  # the citizen almost never needs to make.
  #
  # Three or fewer categories fit as buttons, exactly as the catalog draws them;
  # more become a list, because WhatsApp carries at most three buttons and
  # dropping the rest would hide categories that exist.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return if options.empty?

    @conversation.update!(step: "awaiting_category")

    return send_buttons if options.size <= Whatsapp::DraftCategory::MAX_CHOICE_BUTTONS

    send_list
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def options
      @options ||= Whatsapp::DraftCategory.options_for(@conversation.projekt_phase)
    end

    def body
      I18n.t("whatsapp.bot.proposal.ask_category")
    end

    def send_buttons
      Whatsapp::Outbound.buttons(
        account: account,
        body: body,
        buttons: options.map { |label| { id: row_id(label), title: label.name } }
      )
    end

    def send_list
      Whatsapp::Flows::SendListService.call(
        conversation: @conversation,
        rows: options.map { |label| { id: row_id(label), title: label.name } },
        body: body,
        button_label: I18n.t("whatsapp.bot.buttons.choose_category"),
        empty_body: body
      )
    end

    def row_id(label)
      Whatsapp::FlowActions.id_for(action: :category, param: label.id)
    end
end
