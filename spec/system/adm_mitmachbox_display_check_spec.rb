require "rails_helper"

describe "Mitmachbox display checks in the question and answer forms", type: :system do
  let(:admin) { create(:administrator).user }
  let(:projekt_phase) { create(:mitmachbox_phase) }
  let(:long_label) { Array.new(22) { |i| "Wort#{i}" }.join(" ") }
  let(:long_prompt) { Array.new(40) { "Frage" }.join(" ") }
  let(:questions) do
    [
      { "id" => 1, "position" => 1, "prompt" => "Nutzen Sie die Bibliothek?",
        "question_type" => "single_choice", "required" => false,
        "options" => [{ "id" => 11, "label" => "Ja", "position" => 1 },
                      { "id" => 12, "label" => long_label, "position" => 2 }] }
    ]
  end
  let(:survey) do
    { "id" => 7, "title" => "Umfrage", "state" => "draft", "responses_count" => 0,
      "draft_version" => { "id" => 30, "version_number" => 1 }, "current_version" => nil,
      "current_version_id" => nil }
  end
  let(:client) do
    instance_double(Mitmachbox::Client,
                    surveys: instance_double(Mitmachbox::Resources::Surveys, find: survey),
                    versions: instance_double(Mitmachbox::Resources::Versions,
                                              find: { "id" => 30, "questions" => questions }))
  end
  let(:alert) { "[data-adm--mitmachbox-check-target=alert]" }

  def message(key)
    I18n.t("adm.projekts.mitmachbox.display_check.#{key}")
  end

  before do
    allow(Mitmachbox).to receive(:configured?).and_return(true)
    allow(Mitmachbox::Client).to receive(:new).and_return(client)
    login_as(admin)
  end

  it "warns while typing a question the box cannot show as written" do
    visit new_adm_projekts_phase_mitmachbox_question_path(projekt_phase)
    expect(page).to have_css(alert, visible: :hidden)

    word = "Donaudampfschifffahrtsgesellschaftskapitänsmützenfabrik?"
    fill_in "question[prompt]", with: "Wie finden Sie #{word} 😀"

    within(alert) do
      expect(page).to have_content(word)
      expect(page).to have_content("😀")
    end

    fill_in "question[prompt]", with: "Kurz und gut?"

    expect(page).to have_css(alert, visible: :hidden)
  end

  it "notes a long question that moves to a smaller font" do
    visit new_adm_projekts_phase_mitmachbox_question_path(projekt_phase)

    fill_in "question[prompt]", with: long_prompt

    expect(page).to have_css(alert, text: message(:prompt_shrunk))
  end

  it "flags an existing answer that no longer fits its card under a longer question" do
    visit edit_adm_projekts_phase_mitmachbox_question_path(projekt_phase, 1)
    expect(page).to have_css(alert, visible: :hidden)

    fill_in "question[prompt]", with: long_prompt

    within(alert) { expect(page).to have_content("Wort0 Wort1") }
  end

  it "warns while typing an answer that does not fit its card" do
    visit new_adm_projekts_phase_mitmachbox_question_mitmachbox_option_path(projekt_phase, 1)

    fill_in "option[label]", with: "Romane – Krimis …"

    expect(page).to have_css(alert, visible: :hidden)

    fill_in "option[label]", with: Array.new(40) { |i| "Wort#{i}" }.join(" ")

    expect(page).to have_css(alert, visible: :visible)

    fill_in "option[label]", with: "Mangas 😀"

    within(alert) { expect(page).to have_content("😀") }
  end
end
