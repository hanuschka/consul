require "rails_helper"

describe "Poll question order", type: :request do
  let(:poll) { create(:poll) }
  let!(:first_pinned) { create_question(1, randomize_position: false) }
  let!(:second_pinned) { create_question(5, randomize_position: false) }
  let!(:flagged) do
    [2, 3, 4, 6, 7].map { |order| create_question(order, randomize_position: true) }
  end

  def create_question(given_order, randomize_position:)
    create(:poll_question, poll: poll, given_order: given_order,
                           randomize_position: randomize_position,
                           title: "Question #{given_order}")
  end

  def configured_ids
    poll.questions.root_questions.order(given_order: :asc, id: :asc).pluck(:id)
  end

  def rendered_question_ids
    controller.view_assigns["questions"].map(&:id)
  end

  def visit_poll_as(user)
    login_as(user)
    get poll_path(poll)

    expect(response).to have_http_status(:ok)
  end

  def orders_for_distinct_participants(count)
    Array.new(count) do
      visit_poll_as(create(:user))
      rendered_question_ids
    end
  end

  it "moves the flagged questions out of their configured slots and leaves the others alone" do
    shuffled = orders_for_distinct_participants(4).find { |order| order != configured_ids }

    expect(shuffled).not_to be_nil
    expect(shuffled.values_at(0, 4)).to eq([first_pinned.id, second_pinned.id])
    expect(shuffled.values_at(1, 2, 3, 5, 6)).to match_array(flagged.map(&:id))
  end

  it "orders the flagged questions differently for different participants" do
    expect(orders_for_distinct_participants(4).uniq.size).to be > 1
  end

  it "renders the same order on every request for the same participant" do
    visit_poll_as(create(:user))
    first_order = rendered_question_ids

    get poll_path(poll)

    expect(rendered_question_ids).to eq(first_order)
  end

  it "leaves the configured order alone when no question is flagged" do
    flagged.each { |question| question.update!(randomize_position: false) }

    visit_poll_as(create(:user))

    expect(rendered_question_ids).to eq(configured_ids)
  end

  it "leaves a contextualize template out of the list and renders its clones instead" do
    template = create(:poll_question, poll: poll, given_order: 8,
                                      contextualize_by_poll_question_id: first_pinned.id,
                                      title: "Contextualized question")
    create(:poll_question_answer, question: first_pinned)
    template.regenerate_contexted_clones
    clone = template.contexted_clones.reload.first

    visit_poll_as(create(:user))

    expect(rendered_question_ids).not_to include(template.id)
    expect(rendered_question_ids).to include(clone.id)
  end

  context "in wizard mode" do
    before do
      poll.projekt_phase.settings
          .find_or_create_by!(key: "feature.resource.wizard_mode")
          .update!(value: "active")
    end

    it "places a contexted clone at the position configured for its template" do
      template = create(:poll_question, poll: poll, given_order: 8,
                                        contextualize_by_poll_question_id: first_pinned.id,
                                        title: "Contextualized question")
      create(:poll_question_answer, question: first_pinned)
      template.regenerate_contexted_clones
      clone = template.contexted_clones.reload.first
      clone.update_column(:given_order, 0)

      visit_poll_as(create(:user))

      wizard_ids = controller.view_assigns["wizard_map"].map { |entry| entry[:id] }

      expect(wizard_ids).not_to include(template.id)
      expect(wizard_ids.last).to eq(clone.id)
    end

    it "hands the wizard the same order it renders" do
      visit_poll_as(create(:user))

      wizard_ids = controller.view_assigns["wizard_map"].map { |entry| entry[:id] }

      expect(wizard_ids).to eq(rendered_question_ids)
      expect(wizard_ids.values_at(0, 4)).to eq([first_pinned.id, second_pinned.id])
    end
  end
end
