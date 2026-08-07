class Whatsapp::Flows::AskSentimentService < ApplicationService
  # Asked only when the phase requires a sentiment and the drafting model came
  # back without a valid one. The model is given the phase's sentiments as a
  # closed enum in the same call that writes the title, so this is the exception
  # rather than a step — the same shape as the category question next to it.
  #
  # Three or fewer fit as buttons; more become a list, because WhatsApp carries
  # at most three buttons and dropping the rest would hide options that exist.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return if options.empty?

    @conversation.update!(step: "awaiting_sentiment")

    return send_buttons if options.size <= Whatsapp::DraftSentiment::MAX_CHOICE_BUTTONS

    send_list
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def options
      @options ||= Whatsapp::DraftSentiment.options_for(@conversation.projekt_phase)
    end

    def body
      I18n.t("whatsapp.bot.proposal.ask_sentiment")
    end

    def send_buttons
      Whatsapp::Outbound.buttons(
        account: account,
        body: body,
        buttons: options.map { |sentiment| { id: row_id(sentiment), title: sentiment.name } }
      )
    end

    def send_list
      Whatsapp::Flows::SendListService.call(
        conversation: @conversation,
        rows: options.map { |sentiment| { id: row_id(sentiment), title: sentiment.name } },
        body: body,
        button_label: I18n.t("whatsapp.bot.buttons.choose_sentiment"),
        empty_body: body
      )
    end

    def row_id(sentiment)
      Whatsapp::FlowActions.id_for(action: :sentiment, param: sentiment.id)
    end
end
