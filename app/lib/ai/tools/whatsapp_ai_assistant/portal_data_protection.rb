class Ai::Tools::WhatsappAiAssistant::PortalDataProtection <
  Ai::Tools::WhatsappAiAssistant::BaseTool

  # What the portal does with a citizen's data, as opposed to what one projekt is
  # set up to do. Before this the prompt ruled a projekt's settings out for "was
  # passiert mit meinen Daten?" and put nothing in their place, so the assistant
  # said it did not know — and had no address of the privacy page to offer, since
  # send_link only sends what a tool returned.
  #
  # English on purpose, like Whatsapp::ParticipationRules: read by a model and
  # never by a person, and answered in the citizen's words rather than quoted.
  WHO_SEES_THIS_CHAT = "This chat is not public. Other citizens cannot see it, and nothing " \
                       "written here appears on the portal unless the citizen publishes it as " \
                       "a contribution or a comment. The portal's administrators can read this " \
                       "chat in the portal's administration and can reply in it themselves.".freeze

  PUBLISHED_UNDER = "A published contribution or comment shows the portal username of the " \
                    "linked account, or the organisation's name, and 'Gast' for one sent " \
                    "without an account. The phone number and the WhatsApp profile name are " \
                    "never shown on the portal. Where a phase reviews contributions first, a " \
                    "contribution becomes visible only once the administration has accepted " \
                    "it; projekt_configuration says whether a projekt does.".freeze

  # Unlinking and opting out are named because both sound like deletion and are
  # not: the account link goes, the number stops getting messages, and every
  # stored row stays until the retention periods run out.
  DELETING_DATA = "Deleting the portal account on delete_account_url deletes this chat's " \
                  "record, its messages and the assistant's memory of it together with the " \
                  "account. Unlinking this number or stopping messages deletes nothing by " \
                  "itself; the periods under retention still apply. An unfinished draft of a " \
                  "contribution is kept until it is published or discarded.".freeze

  # Named by what they do rather than by vendor: the language model is whichever
  # the portal has configured, and a name written here would go stale with it.
  PROCESSORS = "Messages travel through WhatsApp (Meta) and the portal's WhatsApp service " \
               "provider. To write replies, the citizen's messages are processed by an " \
               "external AI language model service, and voice messages are transcribed by an " \
               "AI speech-recognition service. The privacy page is the reference for the " \
               "details.".freeze

  HINT = "Answer what was asked from these facts, in your own words, and offer the privacy " \
         "page with send_link (privacy_url) whenever the question is about their data. For " \
         "anything these facts do not cover — the legal basis, who the data controller is, " \
         "transfers abroad — say the privacy page answers it and send that link rather than " \
         "guessing.".freeze

  description "Reads what this portal does with a citizen's data and who can see what they " \
              "write — this chat itself, what they publish, how long messages are kept, which " \
              "services process them, how to have everything deleted — together with the " \
              "address of the privacy page and of the page where the account is deleted. Call " \
              "it for any question about personal data, privacy, storage, deletion or who can " \
              "read the chat, before you say you do not know: these are facts about the " \
              "portal, not about any projekt, so projekt_configuration holds none of them. " \
              "Returns facts for you to answer in your own words; it sends nothing to the " \
              "citizen itself."

  def execute
    {
      privacy_url: ::Whatsapp::PortalLinks.privacy_url(locale: ::Whatsapp.locale_for(account)),
      delete_account_url: ::Whatsapp::PortalLinks.delete_account_url,
      who_sees_this_chat: WHO_SEES_THIS_CHAT,
      published_under: PUBLISHED_UNDER,
      retention: retention_fact,
      deleting_data: DELETING_DATA,
      processors: PROCESSORS,
      hint: HINT
    }
  end

  private

    # Both periods are the one setting: Whatsapp::PurgeOldMessagesJob deletes the
    # messages by their age and clears the assistant's memory by the chat's idle
    # time, each against the same number of days.
    def retention_fact
      days = ::Whatsapp.retention_days

      "Messages in this chat are deleted automatically #{days} days after they were sent. The " \
        "assistant's memory of the conversation is cleared once the citizen has not written " \
        "for #{days} days."
    end
end
