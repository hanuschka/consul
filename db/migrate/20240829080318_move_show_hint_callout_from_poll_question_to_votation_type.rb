class MoveShowHintCalloutFromPollQuestionToVotationType < ActiveRecord::Migration[6.1]
  def up
    transaction do
      add_column :votation_types, :show_hint_callout, :boolean, default: false

      Poll::Question.all.find_each do |poll_question|
        next unless poll_question.votation_type.present?

        poll_question.votation_type.update(show_hint_callout: poll_question.show_hint_callout)
      end

      remove_column :poll_questions, :show_hint_callout
    end
  end

  def down
    transaction do
      add_column :poll_questions, :show_hint_callout, :boolean, default: false

      VotationType.where(questionable_type: "Poll::Question").find_each do |votation_type|
        votation_type.questionable.update(show_hint_callout: votation_type.show_hint_callout)
      end

      remove_column :votation_types, :show_hint_callout
    end
  end
end
