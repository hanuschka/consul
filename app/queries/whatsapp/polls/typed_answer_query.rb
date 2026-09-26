class Whatsapp::Polls::TypedAnswerQuery < ApplicationQuery
  # Which option of the question a citizen is being asked right now they named in
  # their own words, or nothing.
  #
  # A ballot is answered by tapping, and a citizen who types instead used to have
  # their words handed to the assistant as a fresh request: the sentence "Ich bin
  # dafuer, die Gebuehren zu senken", written under question 1 of 5, went to the
  # topic search and came back as the first question of a different ballot. The
  # answer was recorded nowhere and the ballot they were in was left without a word.
  #
  # Matched on the words rather than on a similarity score over the whole message.
  # A score is the right question for two titles and the wrong one for a sentence
  # held against a five-letter option — the sentence's own length drives the union
  # and the score below any floor that is not itself a false positive.
  #
  # Every significant word of the option has to be named, which is what keeps this
  # from answering for the citizen: "Gebühren senken" is not matched by a message
  # that only says "Gebühren". Two options matched is not a tie to break either —
  # a vote is the one thing in the chat that cannot be taken back, so ambiguity
  # returns nothing and the assistant asks.
  def self.for(conversation:, text:)
    new(conversation: conversation, text: text).call
  end

  def initialize(conversation:, text:)
    @conversation = conversation
    @text = text.to_s
  end

  # A message ending in a question mark, which is the one cheap tell that separates
  # "Gebühren senken" from "Was bedeutet Gebühren senken?". Both name the option and
  # only one of them is a vote, so the question goes to the assistant — which is
  # what a citizen asking something in the middle of a ballot has always been able
  # to do.
  QUESTION_MARK = "?".freeze

  def call
    return if question.blank?
    return if text_words.empty?
    return if @text.strip.end_with?(QUESTION_MARK)

    named = question.question_answers.select { |option| named?(option) }

    return if named.size != 1

    named.first
  end

  private

    # The question the citizen is actually looking at, walked from the recorded
    # answers the way every other step of the ballot is — never the last one this
    # conversation happened to write down, which a branch or an answer given on the
    # page since would have moved past.
    def question
      return @question if defined?(@question)

      @question = position&.question
    end

    def position
      return if poll.blank?
      return if @conversation.user.blank?

      ::Polls::BallotTraversalQuery
        .for(poll: poll, user: @conversation.user)
        .first_owed(
          still_choosing_question_id: @conversation.open_multiple_question_id,
          declined_question_ids: @conversation.declined_poll_question_ids
        )
    end

    def poll
      return @poll if defined?(@poll)

      @poll = ::Poll.find_by(id: @conversation.active_poll_id)
    end

    # An open-answer option asks for the citizen's own words rather than standing
    # for them, and Whatsapp::Polls::RecordAnswerService answers a tap on one by
    # putting the question. Matched here, it would ask for the sentence they have
    # just written.
    def named?(option)
      return false if option.open_answer?

      option_words = TextSimilarity.words(option.title)

      return false if option_words.empty?

      significant = option_words.select { |word| word.length >= TextSimilarity::STEM_PREFIX_LENGTH }

      # "Ja", "Nein", "Pro" — nothing long enough to carry a stem, so the word has
      # to be there whole. A three-letter prefix rule would make every option
      # starting alike the same answer.
      return text_words.intersect?(option_words) if significant.empty?

      significant.all? do |word|
        text_words.any? { |text_word| TextSimilarity.same_stem?(word, text_word) }
      end
    end

    def text_words
      @text_words ||= TextSimilarity.words(@text)
    end
end
