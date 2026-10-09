require "rails_helper"

describe "Progress of a Mitmachbox survey in the projekt footer", type: :system do
  let(:projekt) { create(:projekt) }
  let(:projekt_phase) { create(:mitmachbox_phase, projekt: projekt, active: true) }

  def option(id, label, next_question_id: nil, ends_survey: false)
    { "id" => id, "label" => label, "next_question_id" => next_question_id, "ends_survey" => ends_survey }
  end

  def question(id, prompt, options, type: "multiple_choice", required: false, condition: nil)
    { "id" => id, "prompt" => prompt, "question_type" => type, "required" => required,
      "condition" => condition, "options" => options }
  end

  def single(id, prompt, options, **opts)
    question(id, prompt, options, type: "single_choice", required: true, **opts)
  end

  def progress(current, total = nil)
    key = total ? "progress" : "progress_open"
    I18n.t("custom.projekt_phases.mitmachbox_phase.#{key}")
        .sub("{current}", current.to_s).sub("{total}", total.to_s)
  end

  def expect_progress(current, total = nil)
    expect(page).to have_css(".js-mitmachbox-progress-label", exact_text: progress(current, total))
  end

  def next_question
    click_button I18n.t("custom.projekt_phases.mitmachbox_phase.next_question")
  end

  def previous_question
    click_button I18n.t("custom.projekt_phases.mitmachbox_phase.prev_question")
  end

  before do
    projekt_phase.settings.find_by!(key: "feature.general.answer_survey_online").update!(value: "active")
    allow(Mitmachbox::PublicSurveyService).to receive(:call)
      .and_return("state" => "open", "survey_id" => 7, "version_id" => 42, "questions" => questions)
    login_as(create(:user))
    visit page_path(projekt.page.slug, projekt_phase_id: projekt_phase.id)
  end

  context "when every path has the same length" do
    let(:questions) do
      [
        single(16, "Nutzen Sie die Bücherei?", [
          option(60, "Ja", next_question_id: 17),
          option(61, "Nein", next_question_id: 26),
          option(62, "Keine Angabe", next_question_id: 17)
        ]),
        question(26, "Warum nicht?", [option(106, "Kein Bedarf")],
                 condition: { "question_id" => 16, "option_ids" => [61] }),
        question(27, "Was würde Sie locken?", [option(111, "Auswahl")]),
        question(35, "Wie informieren Sie sich?", [option(147, "Website")]),
        question(17, "Woher kennen Sie uns?", [option(63, "Empfehlung")],
                 condition: { "question_id" => 16, "option_ids" => [60, 62] }),
        question(18, "Was gefällt Ihnen?", [option(68, "Auswahl")],
                 condition: { "question_id" => 16, "option_ids" => [60, 62] }),
        question(19, "Was gefällt Ihnen nicht?", [option(73, "Auswahl")],
                 condition: { "question_id" => 16, "option_ids" => [60, 62] }),
        single(22, "Wie wichtig ist die Bücherei?", [option(87, "Sehr wichtig")])
      ]
    end

    it "shows the total from the start and keeps it while answering" do
      expect_progress(1, 5)

      %w[Ja Nein Keine\ Angabe].each do |label|
        choose label, allow_label_click: true

        expect_progress(1, 5)
      end

      choose "Ja", allow_label_click: true
      next_question

      expect(page).to have_content "Woher kennen Sie uns?"
      expect_progress(2, 5)

      previous_question
      choose "Nein", allow_label_click: true
      next_question

      expect(page).to have_content "Warum nicht?"
      expect_progress(2, 5)
    end
  end

  context "when the paths differ in length" do
    let(:questions) do
      [
        single(1, "Nutzen Sie die Bücherei?", [
          option(11, "Ja"),
          option(12, "Nein", ends_survey: true)
        ]),
        single(2, "Wie oft?", [option(21, "Wöchentlich")]),
        single(3, "Wie wichtig ist die Bücherei?", [option(31, "Sehr wichtig")])
      ]
    end

    it "leaves the total out until the path is settled" do
      expect_progress(1)

      choose "Ja", allow_label_click: true

      expect_progress(1)

      next_question

      expect(page).to have_content "Wie oft?"
      expect_progress(2, 3)
    end
  end
end
