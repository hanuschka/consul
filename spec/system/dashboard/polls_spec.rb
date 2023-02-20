require "rails_helper"

describe "Polls" do
  let!(:proposal) { create(:proposal, :draft) }

  before { login_as(proposal.author) }

  xscenario "Has a link to polls feature" do
    visit proposal_dashboard_path(proposal)

    expect(page).to have_link("Polls")
  end

  xscenario "Create a poll" do
    visit proposal_dashboard_path(proposal)
    click_link "Polls"
    click_link "Create poll"

    start_date = 1.week.from_now
    end_date = 2.weeks.from_now

    fill_in "poll_name", with: "Proposal poll"
    fill_in "poll_starts_at", with: start_date.strftime("%d/%m/%Y")
    fill_in "poll_ends_at", with: end_date.strftime("%d/%m/%Y")
    fill_in "poll_description", with: "Proposal's poll description. This poll..."

    expect(page).not_to have_css("#poll_results_enabled")
    expect(page).not_to have_css("#poll_stats_enabled")

    click_link "Add question"

    fill_in "Question", with: "First question"

    click_link "Add answer"

    fill_in "Answer", with: "First answer"

    click_button "Create poll"
    expect(page).to have_content "Poll created successfully"
    expect(page).to have_content "Proposal poll"
    expect(page).to have_content I18n.l(start_date.to_date)
  end

  describe "Datepicker" do
    xscenario "displays the expected format when changing the date field" do
      visit new_proposal_dashboard_poll_path(proposal)

      fill_in "Start Date", with: "20/02/2002"
      find_field("Start Date").click
      within(".ui-datepicker") { click_link "22" }

      expect(page).to have_field "Start Date", with: "22/02/2002"
    end

    xscenario "is closed after using the browser back button" do
      visit proposal_dashboard_polls_path(proposal)

      click_link "Create poll"
      find_field("Start Date").click

      expect(page).to have_css "#ui-datepicker-div"

      go_back

      expect(page).to have_link "Create poll"
      expect(page).not_to have_css "#ui-datepicker-div"
    end

    xscenario "works after using the browser back button" do
      visit new_proposal_dashboard_poll_path(proposal)
      click_link "Polls"

      expect(page).to have_link "Create poll"

      go_back
      find_field("Start Date").click

      expect(page).to have_css "#ui-datepicker-div"
    end
  end

  xscenario "Create a poll redirects back to form when invalid data" do
    visit proposal_dashboard_path(proposal)
    click_link "Polls"
    click_link "Create poll"

    click_button "Create poll"

    expect(page).to have_content("New poll")
  end

  xscenario "Edit poll is allowed for upcoming polls" do
    poll = create(:poll, related: proposal, starts_at: 1.week.from_now)

    visit proposal_dashboard_polls_path(proposal)

    within "div#poll_#{poll.id}" do
      expect(page).to have_content("Edit survey")

      click_link "Edit survey"
    end

    click_button "Update poll"

    expect(page).to have_content "Poll updated successfully"
  end

  xscenario "Edit poll redirects back when invalid data" do
    poll = create(:poll, related: proposal, starts_at: 1.week.from_now)

    visit proposal_dashboard_polls_path(proposal)

    within "div#poll_#{poll.id}" do
      expect(page).to have_content("Edit survey")

      click_link "Edit survey"
    end

    fill_in "poll_name", with: ""

    click_button "Update poll"

    expect(page).to have_content("Edit poll")
  end

  xscenario "Edit poll is not allowed for current polls" do
    poll = create(:poll, :current, related: proposal)

    visit proposal_dashboard_polls_path(proposal)

    within "div#poll_#{poll.id}" do
      expect(page).not_to have_content("Edit survey")
    end
  end

  xscenario "Edit poll is not allowed for expired polls" do
    poll = create(:poll, :expired, related: proposal)

    visit proposal_dashboard_polls_path(proposal)

    within "div#poll_#{poll.id}" do
      expect(page).not_to have_content("Edit survey")
    end
  end

  xscenario "Edit poll should allow to remove questions" do
    poll = create(:poll, related: proposal, starts_at: 1.week.from_now)
    create(:poll_question, poll: poll)
    create(:poll_question, poll: poll)
    visit proposal_dashboard_polls_path(proposal)
    within "div#poll_#{poll.id}" do
      click_link "Edit survey"
    end

    within ".js-questions" do
      expect(page).to have_css ".nested-fields", count: 2
      within first(".nested-fields") do
        find("a.delete").click
      end
      expect(page).to have_css ".nested-fields", count: 1
    end

    click_button "Update poll"
    visit edit_proposal_dashboard_poll_path(proposal, poll)

    expect(page).to have_css ".nested-fields", count: 1
  end

  xscenario "Edit poll allows users to remove answers" do
    poll = create(:poll, related: proposal, starts_at: 1.week.from_now)
    create(:poll_question, :yes_no, poll: poll)
    visit proposal_dashboard_polls_path(proposal)
    within "div#poll_#{poll.id}" do
      click_link "Edit survey"
    end

    within ".js-questions .js-answers" do
      expect(page).to have_css ".nested-fields", count: 2
      within first(".nested-fields") do
        find("a.delete").click
      end
      expect(page).to have_css ".nested-fields", count: 1
    end

    click_button "Update poll"

    expect(page).to have_content "Poll updated successfully"

    visit edit_proposal_dashboard_poll_path(proposal, poll)

    within ".js-questions .js-answers" do
      expect(page).to have_css ".nested-fields", count: 1
    end
  end

  xscenario "Can destroy poll without responses" do
    poll = create(:poll, related: proposal)

    visit proposal_dashboard_polls_path(proposal)

    within("#poll_#{poll.id}") do
      accept_confirm { click_link "Delete survey" }
    end

    expect(page).to have_content("Survey deleted successfully")
    expect(page).not_to have_content(poll.name)
  end

  xscenario "Can't destroy poll with responses" do
    poll = create(:poll, related: proposal)
    create(:poll_question, poll: poll)
    create(:poll_voter, poll: poll)

    visit proposal_dashboard_polls_path(proposal)

    within("#poll_#{poll.id}") do
      accept_confirm { click_link "Delete survey" }
    end

    expect(page).to have_content("You cannot destroy a survey that has responses")
    expect(page).to have_content(poll.name)
  end

  xscenario "View results not available for upcoming polls" do
    poll = create(:poll, related: proposal, starts_at: 1.week.from_now)

    visit proposal_dashboard_polls_path(proposal)

    within "div#poll_#{poll.id}" do
      expect(page).not_to have_content("View results")
    end
  end

  xscenario "View results available for current polls" do
    poll = create(:poll, :current, related: proposal)

    visit proposal_dashboard_polls_path(proposal)

    within "div#poll_#{poll.id}" do
      expect(page).to have_content("View results")
    end
  end

  xscenario "View results available for expired polls" do
    poll = create(:poll, :expired, related: proposal)

    visit proposal_dashboard_polls_path(proposal)

    within "div#poll_#{poll.id}" do
      expect(page).to have_content("View results")
    end
  end

  xscenario "View results redirects to results in public zone" do
    poll = create(:poll, :expired, related: proposal)

    visit proposal_dashboard_polls_path(proposal)

    within_window(window_opened_by { click_link "View results" }) do
      expect(page).to have_current_path(results_proposal_poll_path(proposal, poll))
    end
  end

  xscenario "Enable and disable results" do
    create(:poll, related: proposal)

    visit proposal_dashboard_polls_path(proposal)
    check "Show results"

    expect(find_field("Show results")).to be_checked

    uncheck "Show results"

    expect(find_field("Show results")).not_to be_checked
  end

  xscenario "Poll card" do
    poll = create(:poll, :expired, related: proposal)

    visit proposal_dashboard_polls_path(proposal)

    within "div#poll_#{poll.id}" do
      expect(page).to have_content(I18n.l(poll.starts_at.to_date))
      expect(page).to have_content(I18n.l(poll.ends_at.to_date))
      expect(page).to have_link(poll.title)
      expect(page).to have_link(poll.title, href: proposal_poll_path(proposal, poll))
      expect(page).to have_link("View results", href: results_proposal_poll_path(proposal, poll))
    end
  end
end
