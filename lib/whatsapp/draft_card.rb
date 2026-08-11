module Whatsapp::DraftCard
  # How an unpublished draft is shown to the citizen it belongs to. The card is
  # sent twice on the way to publishing — once to approve the wording, once to
  # approve the picture — and the two must read as the same thing seen again.
  #
  # A WhatsApp interactive body holds 1024 characters, which the intro, the
  # category, the sentiment, the evaluation and the question all draw on before
  # the description does. This leaves room for them.
  DESCRIPTION_PREVIEW_LENGTH = 700

  module_function

  # `intro_key` names the sentence above the card — the first draft, a revised
  # one, the preview before publishing. It is the one part the bot rephrases;
  # the card under it is the citizen's own words and is never touched.
  def body(resource, intro_key:)
    [
      ::Whatsapp::AiAssistant::PhrasingService.call(key: intro_key),
      I18n.t(
        "whatsapp.bot.proposal.card",
        title: resource.title,
        description: plain_description(resource)
      )
    ].join("\n\n")
  end

  # The description is rich text written by the drafting model and edited
  # through the portal, and WhatsApp renders no markup at all.
  def plain_description(resource)
    ActionController::Base.helpers
      .strip_tags(resource.description.to_s)
      .squish
      .truncate(DESCRIPTION_PREVIEW_LENGTH)
  end
end
