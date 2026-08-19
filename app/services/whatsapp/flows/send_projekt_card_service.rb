class Whatsapp::Flows::SendProjektCardService < Whatsapp::Flows::BaseService
  # The one shape the bot names a projekt in: title, a summary of what it is
  # about, link and the projekt's own header picture. Every reply that points at a single projekt
  # goes through here, so a projekt named in passing looks the same as one
  # offered by the submission flow.
  #
  # Buttons decide the message type rather than an option: WhatsApp needs at
  # least one button for an interactive message, so a card without them is an
  # image with a caption instead. Both degrade to plain text when the projekt
  # has no picture WhatsApp will take.
  BODY_MAX_LENGTH = 1024
  SEPARATOR = "\n\n".freeze

  def initialize(conversation:, projekt:, buttons: [])
    super(conversation: conversation)
    @projekt = projekt
    @buttons = buttons
  end

  def call
    return send_with_buttons if @buttons.present?

    send_without_buttons
  end

  private

    def send_with_buttons
      Whatsapp::Send.buttons(
        account: account,
        body: body,
        buttons: @buttons,
        header_image_url: image_url
      )
    end

    def send_without_buttons
      return Whatsapp::Send.text(account: account, body: body) if image_url.blank?

      Whatsapp::Send.image(account: account, image_url: image_url, caption: body)
    end

    def image_url
      return @image_url if defined?(@image_url)

      @image_url = Whatsapp::ProjektCard.image_url(@projekt)
    end

    # Title and link are what the citizen cannot do without, so the summary is
    # the part that gives way when the three of them do not fit.
    def body
      @body ||= [title_line, summary, url].compact_blank.join(SEPARATOR)
    end

    def title_line
      "*#{Whatsapp::ProjektLink.title(@projekt)}*"
    end

    # Generated from the projekt's whole context rather than read off the page,
    # so a citizen who is pointed at a projekt is told what it is about before
    # being asked anything. ProjektCard.subtitle is still the shape
    # underneath — it is what the summary service falls back to, and it stays the
    # broadcast template's variable untouched.
    def summary
      Whatsapp::AiAssistant::ProjektSummaryService.call(
        projekt: @projekt, length: summary_budget
      )
    end

    def summary_budget
      BODY_MAX_LENGTH - title_line.length - url.to_s.length - (SEPARATOR.length * 2)
    end

    def url
      @url ||= Whatsapp::ProjektLink.url(@projekt)
    end
end
