class Whatsapp::Flows::SendLoginLinkService < Whatsapp::Flows::BaseService
  # The way out of a refused :number_taken confirmation. Releasing a linkage
  # someone else made is safe only from here: the pill that reaches this entry
  # point can be tapped by nobody but the citizen holding the phone the number
  # belongs to, whereas the link page is opened by whoever has the URL.
  def self.after_switch(conversation:)
    conversation.whatsapp_account.unlink!

    call(conversation: conversation)
  end

  # `intro` is for a caller that already has something to say before the prompt
  # — a refusal that needs an account. It goes above the prompt in the same
  # message rather than in one of its own, so the reason and the way out arrive
  # together, and it is carried into the plain-link fallback too.
  def initialize(conversation:, intro: nil)
    super(conversation: conversation)
    @intro = intro
  end

  # Catalog A2. Linking is the step the whole catalog depends on, so a button
  # that WhatsApp refuses for any reason falls back to the plain link rather
  # than to silence — with its own copy, because the fallback has to say what
  # the link is for without a button to name it.
  def call
    link_url = Whatsapp::Accounts::LinkTokenService.call(account: account)
    @conversation.update!(step: "awaiting_link")

    Whatsapp::Flows::SendLinkButtonService.call(
      conversation: @conversation,
      body: with_intro(Whatsapp.phrase("whatsapp.bot.onboarding.login_prompt")),
      url: link_url,
      button_label: I18n.t("whatsapp.bot.buttons.login"),
      fallback_body: with_intro(
        Whatsapp.phrase("whatsapp.bot.onboarding.login_prompt_with_url", url: link_url)
      )
    )
  end

  private

    def with_intro(prompt)
      [@intro, prompt].compact_blank.join("\n\n")
    end
end
