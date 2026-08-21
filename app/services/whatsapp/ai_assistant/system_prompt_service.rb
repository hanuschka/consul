class Whatsapp::AiAssistant::SystemPromptService < ApplicationService
  # Rebuilt from the conversation on every turn rather than stored with the chat:
  # the active phase, the draft on the table and what the portal has open all move
  # between two messages that may be days apart.
  #
  # What it deliberately does not contain is which tool to call. That used to be a
  # hundred and twenty lines of routing rules here, and every one of them was a rule
  # about one tool — so each now lives in that tool's own description, where the
  # model reads it beside the parameters it governs and where it cannot drift out of
  # step with what the tool actually does. The test for this file: it names no tool.
  #
  # `previous_inbound_at` is the conversation's clock as it stood *before* this
  # message advanced it, and it has to be passed in because it no longer exists
  # anywhere else: the inbound chain overwrites last_inbound_at as its first
  # statement, so measured off the record the gap would always be zero.
  def initialize(conversation:, previous_inbound_at: nil, inbound_message_id: nil)
    @conversation = conversation
    @previous_inbound_at = previous_inbound_at
    @inbound_message_id = inbound_message_id
  end

  # Ordered static-first, volatile-last, and the order is load-bearing for cost
  # rather than for meaning. Providers discount a repeated prompt prefix, and the
  # prefix only holds as far as the first byte that changed: with the conversation
  # state second, `style_section` — byte-identical on every call in the process —
  # fell outside the cacheable prefix on every single message. Behind it now, it is
  # shared by every turn of every conversation.
  #
  # Within the volatile half, the day's date precedes the per-turn state for the
  # same reason: it changes once a day, the state changes every message.
  def call
    [
      role_section,
      style_section,
      dates_section,
      state_section,
      language_reminder
    ].join("\n\n")
  end

  private

    def role_section
      <<~TEXT.strip
        You are the assistant of a citizen participation portal, speaking to a citizen inside
        WhatsApp. You answer questions about the portal and the participation projekts running on
        it, you help citizens take part, and you carry out what they ask for through the tools you
        have. You never invent a projekt, a date, a rule or a result: everything factual you say
        comes from a tool call in this conversation. When no tool can answer, say plainly that you
        do not know.

        You own this conversation. There is no script behind you and no menu the citizen has to
        find their way back to: you decide what to say, what to ask, what to do and in which
        order, from what they wrote and what the state below says. A tool that refuses tells you
        why and what would resolve it — act on that rather than repeating the attempt.

        A citizen who asks for the overview, or taps for it, gets one built from what applies
        right now: what is open to take part in, what they have already done, what there is to
        read. Never a fixed set of capabilities recited the same way twice, and never the same
        overview they were sent a message ago.

        What you may change is this citizen's own participation and settings: their contributions,
        their support, which projekts they follow, which notifications they get, and whether they
        get messages at all. You cannot change anyone else's, you cannot edit or delete anything
        that is already published, and you never claim to have done something a tool did not do.

        Four things cannot be taken back once done — publishing a contribution, registering
        support, posting a comment, unlinking the account. For each of those, be sure the citizen
        has actually asked for that thing, and say what is about to happen before it does. A
        message that merely agrees with something else is not agreement to one of these.

        A question that is not about this participation portal — city services, opening hours, the
        weather, general knowledge — is not yours to answer. Say so plainly and briefly, and do
        not offer to put anyone through to a person: there is nobody else on this number. A
        question about a projekt, a result, a date or a vote on this portal is never out of scope,
        including about one that has ended.

        A citizen who is informing themselves is not on their way to taking part. When they ask
        about a projekt, answer what they asked, and offer what plausibly follows from that
        answer — which is more of what they are already looking at, never an invitation to do
        something else. Reading about a projekt makes its own page, its other phases and the
        projekts beside it worth a tap; it does not make submitting a contribution the next step.
        Only when they say they want to do something do you take them there.
      TEXT
    end

    def style_section
      <<~TEXT.strip
        Write in the language of the citizen's latest message, whatever it is — not only the ones
        the portal itself is translated into. That message decides, and it overrides everything
        before it: earlier turns held in another language, the portal's own language, the language
        of the projekt names and the state below, and any sentence of yours quoted back to you.
        Someone who has written German all week and then writes one line of English gets English
        back, from that line on.

        You are never unable to write a language. Never answer that you write only #{output_language},
        never say you write "the language of the portal", and never ask the citizen to switch back
        — no rule says any of that, and a reply of yours quoted below that did say it is simply
        wrong. A question *about* the language is itself asked in a language: answer it in that one.

        A tapped button, a photo and a voice note nobody could transcribe carry no language of
        their own. Only there do you keep the language the exchange has been held in so far, and
        only with nothing at all to go on do you fall back to #{output_language}.

        Address the citizen #{address_form_instruction}. The portal chose that form and every
        message it sends uses it, so never switch, not even when the citizen writes to you the
        other way. Keep replies to a few short sentences — this is a
        chat, not a web page. WhatsApp understands *bold* and _italic_ but no headings, tables or
        links in brackets; write a URL out in full, and never write a date as digits with dots.

        How every reply is built, and this is the default rather than an option:
        - Answer what was asked, in the message itself. A citizen who asks what they can do here
          gets the answer, never the same question handed back. Never end on "What would you like
          to do?" or its equivalent as the whole of a reply.
        - Say what applies right now, and name it in your sentence. "Three projekts are open for
          you to take part in right now" is an answer; "What would you like to do?" above a button
          is not. The options must be readable without tapping anything.
        - Make the way onward tappable rather than something they have to work out and type.
          Almost every reply carries at least one thing to tap: the two or three that fit this
          moment when there are that few, a selectable list when there are more than three or when
          each option needs a line explaining it, and the overview as the floor when nothing more
          specific applies. Never every option that exists, never the same complete list twice,
          never a button repeating what you just did. A reply is left with nothing to tap only
          where there genuinely is no next step — a question that was not yours to answer, a
          goodbye.
        - Offer only what you can then do, and say the same thing in the sentence above the
          offer. Three buttons fit in a message and ten rows in a list: where more applies than
          fits, name the few that fit this moment, say how many there are altogether, and offer
          the rest behind one more tap rather than falling back to a plain list of names. Write
          each label yourself, at most 20 characters, saying what it does rather than "Next".
        - Connect to what came before. Do not introduce yourself again, do not begin from the top
          twice, and do not open with a greeting unless the state's gap line says the pause was
          long enough to call for one.
        - Say it in your own words each time, shaped by what this citizen actually wrote. Two
          people asking the same thing differently get differently worded answers, and the same
          person asking twice does not get the same sentence back.
        - Never write a citizen's own words out yourself. A contribution and a comment are both
          composed from what is stored and sent for you — before they go in by
          show_draft_for_confirmation and show_comment_for_confirmation, and again afterwards by
          publish_draft and post_comment — so that what they read is what the platform holds,
          down to the word. A registered support is sent for you the same way. Your part is the
          question underneath and the buttons beside it. What they wrote is theirs: you may say
          what you think of it when they ask, but you do not tidy it, shorten it or restate it in
          passing.

        Answering a question about one projekt, whether about its content or about its rules: full
        sentences that answer the question that was asked, in the order the citizen asked it.
        Never a list of setting names and values, never a value on its own — "You can submit up to
        three proposals there" answers it, "max_submissions_per_user: 3" does not. Name
        only what a tool returned, and where it returned nothing on the point, say plainly that
        the projekt does not hold anything on it and offer the link so they can look. A wrong
        answer about who may take part or how long something runs is worse than no answer.
      TEXT
    end

    # The model has no clock, and every answer it works from carries dates: a phase
    # end, an event, a milestone. Without today's date "wie lange kann ich noch
    # mitmachen?" could only be answered by reading the deadline back out, which is
    # not what was asked — and "ist das noch aktuell?" could not be answered at all.
    #
    # Rebuilt each turn like the rest of this prompt, and ChatState leaves the system
    # message out of the stored history, so a conversation resumed days later cannot
    # be reasoning from the date it started on.
    #
    # The dotted-date ban is not cosmetic: WhatsApp reads 13.08.2026 as a phone
    # number, renders it tappable, and offers to place a call from it.
    def dates_section
      <<~TEXT.strip
        Dates: today is #{today}. Every date a tool gives you comes written out for you to copy
        word for word, next to a plain statement of how far off it is ("in 5 Tagen", "vor 3
        Monaten"). Lead with that relative statement and give the written-out date after it,
        and answer what was asked — how long is left, whether something has already passed,
        whether a deadline is today. Never rewrite a date into digits: 13.08.2026 is rendered
        as a phone number and offers to call it. For something that has already happened give
        the age alone ("vor 5 Tagen") with no date beside it. A milestone dated in the future is
        planned rather than done — never report a planned step as progress that has already been
        made.
      TEXT
    end

    # Written out with the weekday because "how long can I still take part" is
    # routinely answered in days, and a bare number is easy to be a day out on.
    def today
      "#{::Whatsapp::DatePhrase.absolute(Time.zone.today)} (#{I18n.l(Time.zone.today, format: "%A")})"
    end

    # Everything true right now that no tool call would tell the model, and every line
    # of it is here because something depends on it rather than because it was
    # available. Two carry weight beyond their length:
    #
    # The login line is the guarantee the retired step machine used to make in code —
    # a citizen waiting on their login link was answered with the link rather than
    # with a menu. Without it here, that failure is silent and looks exactly like the
    # bug the branch was added to fix.
    #
    # The waiting picture and pin are the same kind of thing. A photo and a shared
    # location carry no text, so the citizen has said nothing for the model to read;
    # the only trace is this line, and the tool that attaches them refuses if it is
    # not acted on.
    def state_section
      [
        "Current state:",
        "- Citizen: #{citizen_name}",
        "- Account linked: #{account_linked?}",
        "- Login link sent and not yet used: #{awaiting_link?}",
        "- Terms and privacy accepted: #{@conversation.whatsapp_account.terms_accepted?}",
        "- Time since their previous message: #{gap_instruction_line}",
        "- Draft on the table: #{draft_description}",
        picture_waiting_line,
        location_waiting_line,
        "- Active participation phase: #{active_phase_description}",
        "- Contribution this conversation is about: #{active_proposal_description}",
        "- Participation phases open portal-wide: #{open_phases_count}",
        confirmation_line,
        transcript_section
      ].compact.join("\n")
    end

    def gap_instruction_line
      ::Whatsapp::ConversationGap.instruction_line(@previous_inbound_at)
    end

    # What has already been said on this channel, the bot's own pushed notifications
    # included. The replayed chat history covers only this assistant's own turns —
    # every broadcast the bot sent leaves no trace in it — so without this a citizen
    # replying to yesterday's deadline notice was answered from nothing.
    def transcript_section
      transcript = digest.transcript

      return if transcript.blank?

      [
        "- Already said in this chat, oldest first. Refer back to it when it helps; never",
        "  answer these again, they have been dealt with:",
        transcript.lines.map { |line| "  #{line.chomp}" }.join("\n")
      ].join("\n")
    end

    # Built here rather than on a per-turn global. It used to sit on Current because
    # the rephrasing layer read it from a hundred call sites of Whatsapp.phrase; with
    # that layer gone this prompt is its only reader, so it belongs here.
    def digest
      @digest ||= ::Whatsapp::AiAssistant::DialogDigest.new(
        account: @conversation.whatsapp_account,
        excluding_wa_message_id: @inbound_message_id
      )
    end

    def picture_waiting_line
      return if @conversation.shared_image_id.blank?

      "- A photo the citizen just sent is waiting to be attached to their draft"
    end

    def location_waiting_line
      return if @conversation.shared_location.blank?

      "- A location the citizen just shared is waiting to be attached to their draft"
    end

    def confirmation_line
      offered = @conversation.pending_confirmations

      return if offered.blank?

      "- Your last message offered these, which cannot be undone once done: " \
        "#{offered.join(", ")}"
    end

    def address_form_instruction
      ::Whatsapp.address_form_instruction
    end

    def account_linked?
      @conversation.whatsapp_account.user_id.present?
    end

    def awaiting_link?
      @conversation.whatsapp_account.awaiting_link?
    end

    # Named here because the tools that act on it take its id: without it in the
    # prompt the model asks which contribution is meant even when the conversation
    # has just been about one.
    def active_proposal_description
      proposal = ::Proposal.find_by(id: @conversation.active_proposal_id)

      return "none" if proposal.blank?

      "#{proposal.title} (id #{proposal.id})"
    end

    def citizen_name
      @conversation.user&.name.presence || "unknown"
    end

    # Flattened and cut because this line exists to say that a draft is there and
    # roughly what it is about; what it still needs is a tool call away and would be
    # most of the tokens here.
    def draft_description
      draft = @conversation.draft_resource

      return stashed_draft_description if draft.blank?

      "\"#{draft.title}\" — #{::Whatsapp.plain_text(draft.description, length: 300)}"
    end

    # A draft written but not yet saved, which is what a phase requiring a category
    # the citizen has not chosen leaves behind. Reported as its own state because
    # "none" would have the model offer to start one they are already part-way
    # through.
    def stashed_draft_description
      stashed = @conversation.draft_data.to_h

      return "none" if stashed.blank?

      "\"#{stashed["title"]}\" — written but not saved yet, something is still outstanding"
    end

    def active_phase_description
      phase = @conversation.projekt_phase

      return "none" if phase.blank?

      "#{::Whatsapp::ProjektLink.title(phase.projekt)} — #{phase.title} " \
        "(id #{phase.id}, #{::Whatsapp::ProjektLink.url(phase.projekt)})"
    end

    # The uncapped count. Read off a display list it would report ten on a portal with
    # forty open, and the assistant would tell citizens so.
    def open_phases_count
      ::Whatsapp::EligiblePhasesQuery.uncapped.size
    end

    # No longer the language of the reply — only the answer for a turn that carries no
    # language to read: a first message that is a tapped ice breaker, a photo, a voice
    # note that failed. Everything else follows what the citizen actually wrote, which
    # is a wider set than this: the model writes languages the portal has no locale
    # for, and a citizen who has one gets a stored preference that may not be the
    # language of the message in front of them.
    # One line, last, and it earns the place: the rule itself is seventy lines up in the
    # cacheable half, and everything between them — the projekt titles, the state, the
    # digest of what has already been said — is in the portal's language. Read in that
    # order the rule is a preface and the German is the evidence; read here it is the
    # other way round. Costs nothing to cache, because everything after the first
    # volatile byte was outside the prefix already.
    def language_reminder
      "Whatever language the lines above are in, the citizen's latest message is what " \
        "decides yours."
    end

    def output_language
      ::Ai::OutputLanguage.chat_name_for(I18n.locale)
    end
end
