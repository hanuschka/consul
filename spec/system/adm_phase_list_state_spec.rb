require "rails_helper"

describe "List state on a phase's Vorschläge list", type: :system do
  let(:admin) { create(:administrator).user }
  let(:phase) { create(:proposal_phase) }
  let!(:hidden) do
    create(:proposal, projekt_phase: phase, title: "Gesuchter Vorschlag", hidden_at: Time.current)
  end
  let!(:other) { create(:proposal, projekt_phase: phase, title: "Anderer Vorschlag") }

  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  before { login_as(admin) }

  it "lets the admin remove a filter after a row action answered in place" do
    visit proposals_adm_projekts_phase_path(phase)

    within("thead th[data-field='title']") do
      find("[data-action='table-header#toggleFilterMenu']", match: :first).click
      fill_in "title__search", with: "Gesucht"
      click_button I18n.t("shared.table.filter.apply")
    end
    expect(page).not_to have_css("#proposal_#{other.id}")

    within("#proposal_#{hidden.id}") do
      find(".kern-table__actions-toggle").click
      find(".kern-table__actions-menu a", text: I18n.t("adm.projekts.phases.proposals.table.unhide")).click
    end
    expect(page).to have_no_css("#proposal_#{hidden.id} .kern-table__actions-menu a",
                                text: I18n.t("adm.projekts.phases.proposals.table.unhide"), visible: :all)

    find(".adm-filter-pill__close").click

    expect(page).to have_css("#proposal_#{other.id}")
    expect(page).not_to have_css(".adm-filter-pill")
  end
end
