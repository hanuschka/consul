require "rails_helper"

describe "Proposal description placeholder", type: :system do
  let(:user) { create(:user) }

  let(:projekt_phase) do
    create(:projekt_phase, active: true, start_date: 1.day.ago, end_date: 1.day.from_now).tap do |phase|
      phase.projekt.update!(activated: true)
      ProjektPhaseSetting.create!(projekt_phase: phase,
                                  key: "feature.resource.users_can_create_proposals",
                                  value: "active")
    end
  end

  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  before do
    page.driver.browser.manage.window.resize_to(1280, 800)
    login_as(user)
  end

  def visit_form_with_placeholder(placeholder)
    projekt_phase.update!(resource_form_description_placeholder: placeholder)
    visit new_proposal_path(projekt_phase_id: projekt_phase.id)
    expect(page).to have_css(".ck-editor__editable > .ck-placeholder")
  end

  def placeholder_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const paragraph = document.querySelector(".ck-editor__editable > .ck-placeholder");
        const style = getComputedStyle(paragraph, "::before");
        return {
          lines: Math.round(parseFloat(style.height) / parseFloat(style.lineHeight)),
          right: paragraph.getBoundingClientRect().left + parseFloat(style.left) + parseFloat(style.width),
          editorRight: paragraph.closest(".ck-editor__editable").getBoundingClientRect().right
        };
      })()
    JS
  end

  it "wraps a placeholder longer than the editor instead of cutting it off" do
    visit_form_with_placeholder("Bitte beschreiben Sie Ihren Vorschlag möglichst genau. " * 6)

    metrics = placeholder_metrics

    expect(metrics["lines"]).to be > 1
    expect(metrics["right"]).to be <= metrics["editorRight"]
  end

  it "keeps line breaks entered by the admin" do
    visit_form_with_placeholder("Erste Zeile\nZweite Zeile\nDritte Zeile")

    expect(placeholder_metrics["lines"]).to eq 3
  end
end
