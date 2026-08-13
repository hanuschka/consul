class Whatsapp::AiAssistant::SkipIntentService < ApplicationService
  # Whether a citizen has just declined the optional thing the bot asked for.
  # Both questions carry a skip pill, and both steps understood nothing but the
  # pill and the media itself: "ich hab kein foto" was answered by re-sending the
  # identical upload prompt, and "die adresse weiß ich nicht" counted as the one
  # miss before publishing — the right outcome, reached by treating the citizen
  # as if they had said nothing.
  #
  # Two entry points because a picture and a place are declined in different
  # words, and the wrong list of examples is what makes a judgement like this
  # miss. They share everything else.
  #
  # False on every failure, which IntentCheckService guarantees and which is what
  # both steps did with an unreadable message before this existed.
  def self.for_image(inbound_text:)
    new(
      inbound_text: inbound_text,
      instructions: IMAGE_INSTRUCTIONS,
      question: IMAGE_QUESTION,
      label: "image skip intent"
    ).call
  end

  def self.for_location(inbound_text:)
    new(
      inbound_text: inbound_text,
      instructions: LOCATION_INSTRUCTIONS,
      question: LOCATION_QUESTION,
      label: "location skip intent"
    ).call
  end

  # Both are lopsided towards not skipping, and can afford to be: the citizen who
  # is not understood is asked once more, and at the location step the second
  # miss publishes anyway. A wrong skip is the expensive one — it drops a picture
  # someone was about to send.
  IMAGE_INSTRUCTIONS = <<~TEXT.freeze
    A citizen is submitting a contribution to a participation portal over WhatsApp. The bot has
    asked them for an optional photo to go with it. Decide whether their message means they do not
    want to send one.

    Answer true when they decline the photo, however they phrase it: "kein foto", "ich hab kein
    bild", "ohne bild", "überspringen", "hab grad keins", "brauch ich nicht", "weiter ohne".

    Answer false for everything else: a description of a photo they are about to send, a question
    about what kind of picture is wanted, a correction to the contribution's text, or anything you
    cannot read with confidence as declining.

    When in doubt, answer false.
  TEXT

  IMAGE_QUESTION = "True only when the message declines the optional photo the bot asked for.".freeze

  LOCATION_INSTRUCTIONS = <<~TEXT.freeze
    A citizen is submitting a contribution to a participation portal over WhatsApp. The bot has
    asked them to share an optional location pin for it. Decide whether their message means they do
    not want to or cannot give one.

    Answer true when they decline the pin, however they phrase it: "keine adresse", "weiß ich
    nicht", "ist mir egal", "ohne ort", "überspringen", "geht auch so", "das ist überall in der
    stadt".

    Answer false for everything else — in particular for a message that names a place in words
    rather than declining one ("Hauptstraße 14", "am Bahnhof", "im Stadtpark"), which is an answer
    to the question and not a refusal of it. Also false for a question, a correction to the
    contribution, or anything you cannot read with confidence as declining.

    When in doubt, answer false.
  TEXT

  LOCATION_QUESTION = "True only when the message declines the optional location pin the bot " \
                      "asked for.".freeze

  def initialize(inbound_text:, instructions:, question:, label:)
    @inbound_text = inbound_text
    @instructions = instructions
    @question = question
    @label = label
  end

  def call
    Whatsapp::AiAssistant::IntentCheckService.call(
      inbound_text: @inbound_text,
      instructions: @instructions,
      question: @question,
      label: @label
    )
  end
end
