require "rails_helper"

describe Budgets::Investments::BallotComponent, type: :component, controller: ApplicationController do
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  let(:investment) { create(:budget_investment, feasibility: "feasible", selected: true) }
  let(:budget) { investment.budget }

  def render_for(user)
    sign_in(user)
    ballot = Budget::Ballot.create!(user: user, budget: budget, conditional: true)
    Budget::Ballot::Line.new(ballot: ballot, investment: investment, heading: investment.heading,
                             group: investment.group, budget: budget).save!(validate: false)

    render_inline(described_class.new(investment: investment, investment_ids: [investment.id],
                                      ballot: ballot, top_level_active_projekts: nil,
                                      top_level_archived_projekts: nil))
  end

  before { allow_any_instance_of(Budget).to receive(:balloting?).and_return(true) }

  describe "the note on a vote that waits for verification" do
    it "says the data is being checked when the voter entered it" do
      user = create(:user, first_name: "Erika", last_name: "Muster", date_of_birth: 30.years.ago,
                           city_name: "Röthenbach", plz: "90552", street_name: "Hauptstraße",
                           street_number: "1")

      render_for(user)

      expect(page).to have_content(I18n.t("custom.budgets.investments.investment.unverified_note"))
      expect(page).not_to have_link(href: "/verification")
    end

    it "links to the verification form when the voter has entered no data" do
      render_for(create(:user))

      expect(page).not_to have_content(I18n.t("custom.budgets.investments.investment.unverified_note"))
      expect(page).to have_link(I18n.t("users.verify_account"), href: "/verification")
    end
  end
end
