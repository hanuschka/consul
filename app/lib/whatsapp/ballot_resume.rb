module Whatsapp::BallotResume
  # Whether the ballot question in front of the citizen is put to them again under
  # this turn's reply (Inbound::ProcessMessageService#resume_ballot). Only then do
  # its own buttons follow the reply, so only then does the reply go out as words
  # alone: a way-out or a state pill above the question reads as a second set to
  # choose from. Where the question does not follow — its one re-ask is spent, a
  # submission has taken over, nothing is owed — words alone left the citizen with
  # nothing to tap.
  #
  # The durable half of resume_ballot's conditions; the ones that live only for the
  # turn (an opt-out held back, a ballot message already sent) stay there.
  module_function

  def question_follows_reply?(conversation)
    return false if conversation.active_poll_id.blank?
    return false if conversation.unsaved_submission?

    owed_question_id =
      ::Whatsapp::Polls::OwedQuestionQuery.for(conversation: conversation)&.question&.id

    return false if owed_question_id.blank?

    !conversation.resumed_poll_question_ids.include?(owed_question_id)
  end
end
