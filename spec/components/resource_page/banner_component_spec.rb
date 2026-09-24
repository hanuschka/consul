require "rails_helper"

describe ResourcePage::BannerComponent, type: :component do
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  it "keeps the creation date and the comment count for a proposal" do
    proposal = create(:proposal)
    allow_any_instance_of(ResourcePage::BannerComponent).to receive(:projekt_phase_feature?).and_return(true)

    render_inline(ResourcePage::BannerComponent.new(resource: proposal))

    expect(page).to have_css("h1.resource-page-banner--title", text: proposal.title)
    expect(page).to have_text(I18n.l(proposal.created_at, format: :new_date_with_year))
    expect(page).to have_css("a[href='#comments']")
  end

  it "shows a given date instead of the creation date" do
    plan = create(:municipal_plan, :published)

    render_inline(ResourcePage::BannerComponent.new(resource: plan, date: "Aktualisiert am 09.08.2026"))

    expect(page).to have_text("Aktualisiert am 09.08.2026")
    expect(page).not_to have_text(I18n.l(plan.created_at, format: :new_date_with_year))
  end

  it "renders a resource that has neither comments nor an image" do
    plan = create(:municipal_plan, :published)

    render_inline(ResourcePage::BannerComponent.new(resource: plan))

    expect(page).to have_css(".resource-page-banner--title", text: plan.title)
    expect(page).not_to have_css("a[href='#comments']")
    expect(page).not_to have_css(".resource-page-banner--image")
  end
end
