require "rails_helper"

describe "Flash messages (toasts)" do
  scenario "success flash renders an auto-dismissing toast with icon and inline text" do
    user = create(:user)

    visit "/"
    click_link "Sign in"
    fill_in "Email or username", with: user.email
    fill_in "Password", with: user.password
    click_button "Enter"

    expect(page).to have_css("#notice.toast.toast--success[data-autodismiss='true']")

    within("#notice") do
      expect(page).to have_content("signed in successfully")
      expect(page).to have_css(".toast__icon .fa-check-circle")
    end
  end

  scenario "the close button removes the toast" do
    user = create(:user)

    visit "/"
    click_link "Sign in"
    fill_in "Email or username", with: user.email
    fill_in "Password", with: user.password
    click_button "Enter"

    expect(page).to have_css("#notice.toast")
    within("#notice") { click_button "Close" }
    expect(page).not_to have_css("#notice.toast")
  end

  scenario "error flash renders a persistent alert toast" do
    visit "/"
    click_link "Sign in"
    fill_in "Email or username", with: "nobody@example.com"
    fill_in "Password", with: "wrongpassword123"
    click_button "Enter"

    expect(page).to have_css("#alert.toast.toast--alert[data-autodismiss='false']")
    within("#alert") do
      expect(page).to have_css(".toast__icon .fa-exclamation-circle")
    end
  end
end
