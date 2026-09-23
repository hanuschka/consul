require "rails_helper"

describe "Proposal authoring locale", type: :request do
  let(:source) { I18n.default_locale }
  let(:foreign) { (I18n.available_locales - [source]).first }
  let(:user) { create(:user) }

  let(:projekt_phase) do
    create(:projekt_phase, active: true, start_date: 1.day.ago, end_date: 1.day.from_now).tap do |phase|
      phase.projekt.update!(activated: true)
      ProjektPhaseSetting.create!(projekt_phase: phase,
                                  key: "feature.resource.users_can_create_proposals",
                                  value: "active")
    end
  end

  def field_group
    response.body[/<div class="translatable-fields[^>]*>/]
  end

  def rendered_locale
    response.body[/name="proposal\[translations_attributes\]\[0\]\[locale\]"[^>]*/][/value="([^"]+)"/, 1] ||
      response.body[/value="([^"]+)"[^>]*name="proposal\[translations_attributes\]\[0\]\[locale\]"/, 1]
  end

  def submit_as_browser_would(locale)
    get new_proposal_path(locale: locale, projekt_phase_id: projekt_phase.id)

    post proposals_path(locale: locale), params: {
      proposal: {
        projekt_phase_id: projekt_phase.id,
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

  describe "GET /proposals/new" do
    it "renders the field group for the locale being browsed" do
      get new_proposal_path(locale: foreign, projekt_phase_id: projekt_phase.id)

      expect(field_group).to include(%(data-locale="#{foreign}"))
    end

    it "renders no field group for any other locale" do
      get new_proposal_path(locale: foreign, projekt_phase_id: projekt_phase.id)

      expect(response.body.scan(/translatable-fields[^>]*data-locale="([^"]+)"/).flatten.uniq)
        .to eq [foreign.to_s]
    end

    it "does not hide the field group in a non-default locale" do
      get new_proposal_path(locale: foreign, projekt_phase_id: projekt_phase.id)

      expect(field_group).not_to include("display: none")
    end

    it "does not mark the translation for destruction in a non-default locale" do
      get new_proposal_path(locale: foreign, projekt_phase_id: projekt_phase.id)

      destroy_field = response.body[/<input[^>]*translations_attributes\]\[0\]\[_destroy\][^>]*>/]

      expect(destroy_field).to include(%(value="false"))
    end

    it "renders the field group for the default locale too" do
      get new_proposal_path(locale: source, projekt_phase_id: projekt_phase.id)

      expect(field_group).to include(%(data-locale="#{source}"))
    end
  end

  describe "POST /proposals" do
    it "stores the translation under the locale it was written in" do
      submit_as_browser_would(foreign)

      proposal = Proposal.last

      expect(proposal.translations.pluck(:locale)).to include foreign.to_s
      expect(MachineTranslation.authored_locale(proposal)).to eq foreign
    end

    it "stores the default locale when authored in it" do
      submit_as_browser_would(source)

      expect(MachineTranslation.authored_locale(Proposal.last)).to eq source
    end
  end
end
