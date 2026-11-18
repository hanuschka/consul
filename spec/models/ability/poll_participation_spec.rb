require "rails_helper"
require "cancan/matchers"

describe Ability, "poll participation" do
  let(:citizen) { create(:user) }
  let(:phase) { create(:voting_phase, active: true, user_status: "registered") }
  let(:poll) { phase.poll.tap { |poll| poll.update!(live: true) } }
  let(:question) { create(:poll_question, poll: poll) }

  def with_setting(key, value)
    phase.settings.find_by!(key: key).update!(value: value)
  end

  def project_manager_of(projekt)
    user = create(:user)
    manager = create(:projekt_manager, user: user)
    create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager, permissions: ["manage"])
    user
  end

  describe "answering" do
    it "lets a citizen who meets the restrictions answer and withdraw while the poll is live" do
      answer = create(:poll_question_answer, question: question)
      own_vote = Poll::Answer.create!(question: question, author: citizen, answer: answer.title)

      expect(Ability.new(citizen)).to be_able_to(:answer, question)
      expect(Ability.new(citizen)).to be_able_to(:destroy, own_vote)
    end

    it "does not let a citizen answer or withdraw once the phase has ended" do
      answer = create(:poll_question_answer, question: question)
      own_vote = Poll::Answer.create!(question: question, author: citizen, answer: answer.title)
      phase.update!(end_date: 1.day.ago)

      expect(Ability.new(citizen)).not_to be_able_to(:answer, Poll::Question.find(question.id))
      expect(Ability.new(citizen)).not_to be_able_to(:destroy, Poll::Answer.find(own_vote.id))
    end

    it "does not let anyone withdraw somebody else's answer" do
      answer = create(:poll_question_answer, question: question)
      other_vote = Poll::Answer.create!(question: question, author: create(:user), answer: answer.title)

      expect(Ability.new(citizen)).not_to be_able_to(:destroy, other_vote)
    end
  end

  describe "results" do
    it "are always visible to administrators" do
      expect(Ability.new(create(:administrator).user)).to be_able_to(:results, poll)
    end

    it "are visible to project managers of the projekt" do
      expect(Ability.new(project_manager_of(phase.projekt))).to be_able_to(:results, poll)
    end

    it "are visible to moderators while intermediate results for admins are on" do
      expect(Ability.new(create(:moderator).user)).to be_able_to(:results, poll)
    end

    it "are hidden from moderators when intermediate results for admins are off" do
      with_setting("feature.resource.intermediate_poll_results_for_admins", "")

      expect(Ability.new(create(:moderator).user)).not_to be_able_to(:results, Poll.find(poll.id))
    end

    it "are hidden from citizens by default" do
      expect(Ability.new(citizen)).not_to be_able_to(:results, poll)
    end

    it "are visible to citizens during the phase when public key figures are on" do
      with_setting("feature.general.public_kpi_stats", "active")

      expect(Ability.new(citizen)).to be_able_to(:results, Poll.find(poll.id))
    end
  end

  describe "report tab with the AI summary" do
    it "is hidden from citizens by default" do
      expect(Ability.new(citizen)).not_to be_able_to(:report, poll)
    end

    it "is visible to citizens when the report is switched on for them" do
      phase.projekt.update!(activated: true)
      with_setting("feature.resource.report_visible_for_citizens", "active")

      expect(Ability.new(citizen)).to be_able_to(:report, Poll.find(poll.id))
    end
  end
end
