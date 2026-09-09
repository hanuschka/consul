class Whatsapp::Polls::RecordMapPointService < ApplicationService
  # A location the citizen shared, taken as the answer to the map-point question the
  # bot last asked. It is the one place a shared pin means something other than a
  # place for a contribution being drafted, which is why the question has to have
  # been written down before the pin could arrive — Whatsapp::Conversation
  # #pending_map_question_id is what says it was asked for.
  #
  # The write is the portal's own, lock included: one Poll::Answer per citizen with
  # its `answer` column left null, the points hanging off it as rows, and
  # pg_advisory_xact_lock on the question and the citizen together so two pins
  # arriving at once cannot both find room under the maximum. The lock is the reason
  # the check sits inside the transaction rather than in front of it.
  #
  # A point outside the area the portal drew is refused with the reason and nothing
  # is recorded; the question stays armed, so the next pin is taken as another
  # attempt at the same answer. A question whose points are all placed settles and
  # the ballot moves on.
  # The question left unanswered on purpose, from the pill that follows the picker.
  # Nothing is recorded — a map question that was never answered has no rows to
  # remove — and the ballot carries on, because a place the citizen would rather not
  # give is not a reason to end it.
  def self.skip(conversation:)
    new(conversation: conversation, latitude: nil, longitude: nil).skip!
  end

  def initialize(conversation:, latitude:, longitude:)
    @conversation = conversation
    @latitude = latitude
    @longitude = longitude
  end

  def call
    return false if !asked?
    return abandon if !still_votable?
    return refuse_outside_area if !inside_area?

    point = place_point!

    return refuse_over_maximum if point.blank?

    confirm(point)
    settle_question!

    advance
  end

  def skip!
    return false if question.blank? || !question.map_points? || user.blank?
    return abandon if !still_votable?

    @conversation.decline_poll_question!(question.id)
    @conversation.clear_pending_map_question!

    advance
  end

  private

    # That a map-point question was actually put to this citizen. Without it any
    # shared pin would be a candidate answer to whatever question a marker happened
    # to name.
    def asked?
      question.present? && question.map_points? && user.present? &&
        @latitude.present? && @longitude.present?
    end

    # The marker alone is not enough: it survives in the conversation while the poll
    # behind it can close, so the whole gate is asked again before a pin is taken as
    # a vote.
    def still_votable?
      poll.present? && projekt_phase.permission_problem(user).blank?
    end

    # The markers go and the pin goes to the assistant, which is where a pin nobody
    # asked for belonged anyway.
    def abandon
      @conversation.clear_ballot!

      false
    end

    # The belt behind Whatsapp::VotableBallotQuery, which keeps a poll whose area
    # cannot be tested out of the chat in the first place. If one reaches here anyway
    # the point is refused rather than allowed to raise: an exception in the inbound
    # path is a message the citizen gets no answer to at all.
    def inside_area?
      boundary.contains?(@latitude, @longitude)
    rescue StandardError => e
      Rails.logger.error("[Whatsapp::Polls::RecordMapPointService] untestable area: #{e.message}")

      false
    end

    def boundary
      @boundary ||= ::Polls::MapPointBoundary.new(question)
    end

    # The portal's own write, in the portal's own order. Answers the point it placed,
    # or nothing where the maximum was already reached — which is read under the lock
    # rather than before it, because that is the whole reason there is a lock.
    def place_point!
      placed = nil

      ::Poll::Answer.transaction do
        lock_points_for_user!
        answer = existing_answer

        if answer.blank? || answer.map_points.count < question.max_map_points
          answer ||= create_answer!
          placed = answer.map_points.create!(latitude: @latitude, longitude: @longitude)
        end
      end

      placed
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[Whatsapp::Polls::RecordMapPointService] refused: #{e.message}")

      nil
    end

    def lock_points_for_user!
      ::Poll::Answer.connection.execute(
        "SELECT pg_advisory_xact_lock(#{question.id.to_i}, #{user.id.to_i})"
      )
    end

    def existing_answer
      question.answers.find_by(author: user)
    end

    def create_answer!
      answer = question.answers.new(author: user)
      answer.save_and_record_voter_participation

      answer
    end

    # What was recorded, said back in a form the citizen can check. The chat has no
    # map to show them the pin on, and the coordinates are not something a person can
    # read, so the place is named in words where the lookup can name it
    # (Polls::MapPointAddress) and the count of what is still wanted carries the rest.
    #
    # The address is composed in after the bot's own lines are translated rather than
    # interpolated into one of them, for the reason the poll's name is: it is not the
    # bot's wording, and an address that has been through a model is an address that
    # may have been rewritten into something the citizen cannot check.
    def confirm(point)
      address = ::Polls::MapPointAddress.new(
        latitude: point.latitude, longitude: point.longitude
      ).call

      recorded, remaining = translated(
        ::Whatsapp.copy("whatsapp.bot.poll.location_recorded"), remaining_text
      )

      ::Whatsapp::Send.text(
        account: account, body: [recorded, address, remaining].compact_blank.join("\n\n")
      )
    end

    def remaining_text
      remaining = question.max_map_points - placed_points

      return if remaining < 1

      ::Whatsapp.copy("whatsapp.bot.poll.location_remaining", remaining: remaining)
    end

    # One call for the whole message, because BotCopyService rewrites a message's
    # lines together: asked one at a time, the confirmation and the count under it
    # can come back in two different languages.
    def translated(*lines)
      ::Whatsapp::AiAssistant::BotCopyService.call(
        account: account, lines: lines.map(&:to_s)
      )
    end

    # Reached where a pin arrives for a question that already holds all the points it
    # asked for — a second one sent while the first was still being written, or a
    # picker left open above. Said rather than silently dropped, and the question is
    # settled so the ballot is not left standing on it.
    def refuse_over_maximum
      ::Whatsapp::Send.locale_text(
        account: account,
        body: I18n.t(
          "whatsapp.bot.poll.location_maximum_reached", maximum: question.max_map_points
        )
      )

      settle_question!

      advance
    end

    # The area is the question's own (Polls::MapPointBoundary reads its map_location),
    # so the reason names the question rather than the portal. Nothing is recorded and
    # the question stays armed: the next pin is another attempt at the same answer.
    def refuse_outside_area
      ::Whatsapp::Send.locale_text(
        account: account, body: ::Whatsapp.copy("whatsapp.bot.poll.location_outside_area")
      )

      true
    end

    # The question is answered once it holds every point it asked for. Until then the
    # marker stays, and the walk hands the same question back so the next pin can be
    # sent — which is what Polls::BallotTraversalQuery reads the point count for.
    def settle_question!
      return if placed_points < question.max_map_points

      @conversation.clear_pending_map_question!
    end

    # Read once, after the write: the confirmation and the settle both want it, and
    # nothing between them can change it.
    def placed_points
      @placed_points ||= ::Poll::Answer::MapPoint
        .for_question(question)
        .where(poll_answers: { author_id: user.id })
        .count
    end

    def advance
      @conversation.store_active_poll!(poll.id)

      ::Whatsapp::Polls::AdvanceBallotService.call(conversation: @conversation, poll: poll)
    end

    def question
      return @question if defined?(@question)

      question_id = @conversation.pending_map_question_id

      @question = question_id.blank? ? nil : ::Poll::Question.find_by(id: question_id)
    end

    def poll
      return @poll if defined?(@poll)

      @poll = ::Whatsapp::VotableBallotQuery.for(projekt_phase)
    end

    def projekt_phase
      @projekt_phase ||= question&.poll&.projekt_phase
    end

    def account
      @conversation.whatsapp_account
    end

    def user
      @conversation.user
    end
end
