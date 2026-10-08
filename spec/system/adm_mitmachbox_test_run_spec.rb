require "rails_helper"

describe "Mitmachbox test run on the drawn box", type: :system do
  let(:admin) { create(:administrator).user }
  let(:projekt_phase) { create(:mitmachbox_phase) }
  let(:questions) do
    [
      { "id" => 1, "position" => 1, "prompt" => "Nutzen Sie die Bibliothek?",
        "question_type" => "single_choice", "required" => true,
        "options" => [
          { "id" => 11, "label" => "Ja", "position" => 1, "next_question_id" => 2, "ends_survey" => false },
          { "id" => 12, "label" => "Nein", "position" => 2, "next_question_id" => nil, "ends_survey" => true }
        ] },
      { "id" => 2, "position" => 2, "prompt" => "Was lesen Sie?", "question_type" => "multiple_choice",
        "required" => false,
        "options" => [
          { "id" => 21, "label" => "Romane", "position" => 1, "next_question_id" => nil,
"ends_survey" => false },
          { "id" => 22, "label" => "Sachbücher", "position" => 2, "next_question_id" => nil,
"ends_survey" => false }
        ] }
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

  before do
    allow(Mitmachbox).to receive(:configured?).and_return(true)
    allow(Mitmachbox::Client).to receive(:new).and_return(client)
    login_as(admin)
  end

  def ink_in(top, bottom, left = 0, right = 800)
    page.evaluate_script(<<~JS)
      (() => {
        const canvas = document.querySelector(".adm-mitmachbox-box__screen")
        const sx = canvas.width / 800, sy = canvas.height / 480
        const x0 = Math.floor(#{left} * sx), x1 = Math.ceil(#{right} * sx)
        const y0 = Math.floor(#{top} * sy), y1 = Math.ceil(#{bottom} * sy)
        const data = canvas.getContext("2d").getImageData(x0, y0, Math.max(1, x1 - x0), Math.max(1, y1 - y0)).data
        let ink = 0
        for (let i = 0; i < data.length; i += 4) if (data[i] < 100) ink++
        return ink
      })()
    JS
  end

  def settled_ink(*region)
    previous = nil
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        current = ink_in(*(region.presence || [0, 480]))
        return current if current.positive? && current == previous

        previous = current
        sleep 0.3
      end
    end
  end

  def start_block_ink
    settled_ink(179, 251, 624, 800)
  end

  def status_line_ink
    settled_ink(126, 158, 470, 800)
  end

  def visit_test_run
    visit mitmachbox_test_run_adm_projekts_phase_path(projekt_phase, version: "draft")
    expect(page).to have_css(".adm-mitmachbox-box__screen")
  end

  def start_run
    visit_test_run
    welcome = start_block_ink
    find(".adm-mitmachbox-box__key--6").click
    expect(page).to have_css("legend", text: "Nutzen Sie die Bibliothek?", visible: :all)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.2 until ink_in(179, 251, 624, 800) < welcome / 4
    end
  end

  it "opens on the welcome screen and starts the run with key 6" do
    visit_test_run

    expect(start_block_ink).to be > 0
    expect(page).not_to have_css("legend", visible: :all)

    find(".adm-mitmachbox-box__key--6").click

    expect(page).to have_css("legend", text: "Nutzen Sie die Bibliothek?", visible: :all)
  end

  it "fills the chosen answer card and presses its key down" do
    start_run
    before = settled_ink(160, 480)

    find(".adm-mitmachbox-box__key--1").click

    expect(page).to have_css(".adm-mitmachbox-box__key--1.is-down")
    expect(find("#mitmachbox-test-run-option-11", visible: :all)).to be_checked
    expect(settled_ink(160, 480)).to be > before
  end

  it "keeps a required question and shows the hint in the line above the cards" do
    start_run
    cards_before = settled_ink(160, 480)
    status_before = status_line_ink

    find(".adm-mitmachbox-box__key--6").click

    expect(page).to have_css("[role=alert]", text: I18n.t("adm.projekts.phases.mitmachbox_test_run.required"),
                                             visible: :all)
    expect(status_line_ink).not_to eq status_before
    expect(settled_ink(160, 480)).to eq cards_before

    find(".adm-mitmachbox-box__key--1").click

    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.2 until status_line_ink == status_before }
  end

  it "answers with key 1 and moves on with key 6" do
    start_run

    find(".adm-mitmachbox-box__key--1").click
    expect(page).to have_css(".adm-mitmachbox-box__key--1.is-down")
    find(".adm-mitmachbox-box__key--6").click

    expect(page).to have_css("legend", text: "Was lesen Sie?", visible: :all)
    expect(settled_ink(160, 480)).to be > 0
  end

  it "shows the firmware's thank-you screen with its check mark at the end" do
    visit mitmachbox_test_run_adm_projekts_phase_path(projekt_phase,
                                                      version: "draft",
                                                      answered: 1,
                                                      answers: { "1" => ["12"] })
    restart_path = mitmachbox_test_run_adm_projekts_phase_path(projekt_phase, version: "draft")

    expect(page).to have_link(href: restart_path)
    expect(settled_ink(124, 240, 342, 458)).to be > ink_in(124, 240, 0, 116) + 1000
    expect(settled_ink(280, 360)).to be > 0
    expect(ink_in(0, 110)).to eq 0
  end
end
