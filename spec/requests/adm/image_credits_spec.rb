require "rails_helper"

describe "Image credits in /adm", type: :request do
  let(:admin) { create(:administrator).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def projekt_manager_with(projekt, *permissions)
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, *permissions, projekt: projekt, projekt_manager: manager)
    manager.user
  end

  def attach_image(imageable)
    image = imageable.build_image(user: admin)
    image.attachment.attach(io: file_fixture("clippy.jpg").open, filename: "clippy.jpg")
    image.save!(validate: false)
    image
  end

  describe "poll image" do
    let(:poll) { create(:poll) }
    let!(:image) { attach_image(poll) }

    def update_credits(value)
      patch adm_attribute_path(record_type: "image", id: image.id),
            params: {
              attribute: "credits",
              kind: "string",
              field_token: Adm::AttributeEditorToken.generate(image, "credits", "string"),
              image: { credits: value }
            },
            as: :turbo_stream
    end

    it "saves a credit and clears it again" do
      login_as(admin)

      update_credits("©Stadt Rheinfelden (Baden)")
      expect(image.reload.credits).to eq "©Stadt Rheinfelden (Baden)"

      update_credits("")
      expect(image.reload.credits).to be_blank
    end

    it "works for a projekt manager who manages the projekt" do
      login_as(projekt_manager_with(poll.projekt, :manage))

      update_credits("©name_stock.adobe.com")

      expect(image.reload.credits).to eq "©name_stock.adobe.com"
    end

    it "is refused to a projekt manager without the manage permission" do
      login_as(projekt_manager_with(poll.projekt, :moderate))

      update_credits("©name_stock.adobe.com")

      expect(image.reload.credits).to be_nil
    end
  end

  describe "Projektstudio banner" do
    let(:projekt) { create(:projekt) }
    let!(:image) { attach_image(projekt.page) }

    def update_credits(value)
      patch update_image_credits_adm_projekts_projekt_path(projekt), params: { credits: value }, as: :json
    end

    it "lets a projekt manager who manages the projekt save and clear a credit" do
      login_as(projekt_manager_with(projekt, :manage))

      update_credits("©Martin Schulte-Kellinghaus")

      expect(image.reload.credits).to eq "©Martin Schulte-Kellinghaus"
      expect(response.parsed_body["credit_html"]).to include("image-credit-label", "©Martin Schulte-Kellinghaus")

      update_credits(" ")

      expect(image.reload.credits).to be_nil
      expect(response.parsed_body["credit_html"]).to be_nil
    end

    it "is refused to a projekt manager without the manage permission" do
      login_as(projekt_manager_with(projekt, :moderate))

      update_credits("©name_stock.adobe.com")

      expect(image.reload.credits).to be_nil
    end
  end

  describe "homepage header image" do
    let(:header_image) do
      image = SiteCustomization::Image.find_or_create_by!(name: "header_image")
      image.update!(credits: "©Alter Fotograf")
      image.image.attach(io: file_fixture("clippy.jpg").open, filename: "clippy.jpg")
      image
    end

    it "refreshes the cleared credit field when the image is replaced" do
      login_as(admin)

      patch adm_attribute_path(record_type: "site_customization-image", id: header_image.id),
            params: {
              attribute: "image",
              kind: "image",
              field_token: Adm::AttributeEditorToken.generate(header_image, "image", "image"),
              site_customization_image: { image: fixture_file_upload("clippy.png", "image/png") }
            },
            as: :turbo_stream

      expect(header_image.reload.credits).to be_nil
      expect(response.body).to include(%(target="credits_editor_site_customization_image_#{header_image.id}"))
      expect(response.body).not_to include("©Alter Fotograf")
    end
  end

  describe "budget investment edit form" do
    let(:investment) { create(:budget_investment) }
    let!(:image) { attach_image(investment) }

    def update_credits(value)
      patch adm_projekts_phase_budget_investment_path(investment.budget.projekt_phase, investment),
            params: { budget_investment: { image_attributes: { id: image.id, credits: value } } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "saves a credit and clears it again" do
      login_as(admin)

      update_credits("©Stadt Rheinfelden (Baden)")
      expect(image.reload.credits).to eq "©Stadt Rheinfelden (Baden)"

      update_credits("")
      expect(image.reload.credits).to be_blank
    end
  end
end
