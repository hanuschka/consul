require "rails_helper"

describe "Returning to the /adm user list", type: :system do
  let(:admin) { create(:administrator).user }
  let!(:oldest) { create(:user, username: "Ältester", created_at: 2.days.ago) }

  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  before do
    create_list(:user, 20, created_at: 1.day.ago)
    login_as(admin)
  end

  def open_row_action(user, label)
    within("#user_#{user.id}") do
      find(".kern-table__actions-toggle").click
      find(".kern-table__actions-menu a", text: label).click
    end
  end

  def edit_oldest
    open_row_action(oldest, I18n.t("adm.users.user.table.actions.edit"))

    expect(page).to have_field("user_first_name")
  end

  def save_form
    find("form button[type=submit]", text: I18n.t("shared.submit"), match: :first).click

    expect(page).to have_content(I18n.t("adm.users.flash.updated"))
  end

  def go_to_second_page
    within("turbo-frame#users_table") { click_link "2", exact_text: true }

    expect_only_oldest_listed
  end

  def search_usernames(term)
    within("thead th[data-field='username']") do
      find("[data-action='table-header#toggleFilterMenu']", match: :first).click
      fill_in "username__search", with: term
      click_button I18n.t("shared.table.filter.apply")
    end

    expect_only_oldest_listed
  end

  def expect_only_oldest_listed
    expect(page).to have_css("#user_#{oldest.id}")
    expect(page).not_to have_css("#user_#{admin.id}")
  end

  it "returns to the page the admin left after saving an edit" do
    visit adm_users_path
    go_to_second_page

    edit_oldest
    fill_in "user_first_name", with: "Berta"
    save_form

    expect_only_oldest_listed
    expect(oldest.reload.first_name).to eq "Berta"
  end

  it "returns to the search results via the back button, without saving" do
    visit adm_users_path
    search_usernames("Ältes")

    edit_oldest
    page.execute_script("Turbo.cache.clear()")
    find(".breadcrumb-back-button").click

    expect_only_oldest_listed
  end

  it "returns to the search results after saving an edit" do
    visit adm_users_path
    search_usernames("Ältes")

    edit_oldest
    save_form

    expect_only_oldest_listed
  end

  it "stays on the page the admin left after an action from the row menu" do
    oldest.update!(verified_at: 1.day.ago)

    visit adm_users_path
    go_to_second_page

    open_row_action(oldest, I18n.t("adm.users.user.table.actions.unverify"))

    expect(page).to have_css("#user_#{oldest.id} a[href$='/verify']", visible: :all)
    expect_only_oldest_listed
    expect(oldest.reload.verified_at).to be nil
  end

  it "starts on page 1 without a search when opened from the navigation" do
    visit adm_users_path
    go_to_second_page

    edit_oldest
    within("nav.adm-menu") { find("a[href='#{adm_users_path}']").click }

    expect(page).to have_css("#user_#{admin.id}")
    expect(page).not_to have_css("#user_#{oldest.id}")
  end

  it "starts on page 1 again after switching sections in the icon rail" do
    visit adm_users_path
    go_to_second_page

    first(".adm-icon-rail__item").click
    expect(page).not_to have_current_path(adm_users_path)

    visit adm_users_path

    expect(page).to have_css("#user_#{admin.id}")
    expect(page).not_to have_css("#user_#{oldest.id}")
  end
end
