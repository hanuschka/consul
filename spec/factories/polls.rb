FactoryBot.define do
  factory :poll do
    projekt_phase { create(:projekt_phase, :voting_phase) }
    sequence(:name) { |n| "Poll #{n}" }
  end

  factory :poll_question, class: "Poll::Question" do
    poll
    author { create(:user) }
    sequence(:title) { |n| "Question #{n}" }
    votation_type { VotationType.new(vote_type: :unique) }

    trait :bundle do
      bundle_question { true }
    end

    trait :map_points do
      votation_type { VotationType.new(vote_type: :map_points, max_votes: 3) }
    end
  end

  factory :poll_question_answer, class: "Poll::Question::Answer" do
    question { create(:poll_question) }
    sequence(:title) { |n| "Answer #{n}" }
    sequence(:given_order) { |n| n }

    trait :open_answer do
      open_answer { true }
    end
  end
end
