require "rails_helper"

describe "Budget investment authoring locale", type: :request do
  let(:source) { I18n.default_locale }
  let(:foreign) { (I18n.available_locales - [source]).first }
  let(:user) { create(:user) }
  let(:budget) do
    create(:budget, :with_heading, :accepting_now).tap do |record|
      ProjektPhaseSetting.create!(projekt_phase: record.projekt_phase,
                                  key: "feature.resource.users_can_create_investment_proposals",
                                  value: "active")
    end
  end

  def field_group
    response.body[/<div class="translatable-fields[^>]*>/]
  end

  def rendered_locale
    response.body[/name="budget_investment\[translations_attributes\]\[0\]\[locale\]"[^>]*/][/value="([^"]+)"/, 1] ||
      response.body[/value="([^"]+)"[^>]*name="budget_investment\[translations_attributes\]\[0\]\[locale\]"/, 1]
  end

  def submit_as_browser_would(locale)
    get new_budget_investment_path(budget, locale: locale)

    post budget_investments_path(budget, locale: locale), params: {
      budget_investment: {
        resource_terms: "1",
        translations_attributes: {
          "0" => {
            locale: rendered_locale,
            title: "A bench by the river",
            description: "There is nowhere to sit along the path."
          }
        }
      }
    }
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    InvisibleCaptcha.timestamp_enabled = false
    login_as(user)
  end

  after { InvisibleCaptcha.timestamp_enabled = true }

  describe "GET /budgets/:id/investments/new" do
    it "renders the field group for the locale being browsed" do
      get new_budget_investment_path(budget, locale: foreign)

      expect(field_group).to include(%(data-locale="#{foreign}"))
    end

    it "renders no field group for any other locale" do
      get new_budget_investment_path(budget, locale: foreign)

      expect(response.body.scan(/translatable-fields[^>]*data-locale="([^"]+)"/).flatten.uniq)
        .to eq [foreign.to_s]
    end

    it "does not hide the field group in a non-default locale" do
      get new_budget_investment_path(budget, locale: foreign)

      expect(field_group).not_to include("display: none")
    end

    it "renders the field group for the default locale too" do
      get new_budget_investment_path(budget, locale: source)

      expect(field_group).to include(%(data-locale="#{source}"))
    end
  end

  describe "POST /budgets/:id/investments" do
    it "stores the translation under the locale it was written in" do
      submit_as_browser_would(foreign)

      investment = Budget::Investment.last

      expect(investment.translations.pluck(:locale)).to include foreign.to_s
      expect(MachineTranslation.authored_locale(investment)).to eq foreign
    end

    it "stores the default locale when authored in it" do
      submit_as_browser_would(source)

      expect(MachineTranslation.authored_locale(Budget::Investment.last)).to eq source
    end
  end
end
