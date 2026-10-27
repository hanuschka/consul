require "rails_helper"

describe UserResources::ImageUploadComponent, type: :component do
  let(:user) { create(:user) }

  before { allow(vc_test_controller).to receive(:current_user).and_return(user) }

  def render_for(imageable)
    imageable.build_image
    vc_test_controller.view_context.form_for(imageable, url: "/") do |f|
      f.fields_for(:image) do |image_builder|
        render_inline(described_class.new(image_builder, imageable: imageable))
      end
    end
  end

  shared_examples "image upload placeholder without help sentence" do
    it "renders the title and hints but no help sentence" do
      render_for(imageable)

      expect(page).not_to have_text("Wählen Sie ein passendes Bild")
      expect(page).not_to have_text("Choose a fitting image")
      expect(page).to have_css(".user-resource-image-upload--label-title")
      expect(page).to have_css(".user-resource-image-upload--hint", count: 3)
    end
  end

  context "for a proposal" do
    let(:imageable) { build(:proposal) }

    include_examples "image upload placeholder without help sentence"
  end

  context "for a debate" do
    let(:imageable) { Debate.new }

    include_examples "image upload placeholder without help sentence"
  end

  context "for a deficiency report" do
    let(:imageable) { build(:deficiency_report) }

    include_examples "image upload placeholder without help sentence"
  end
end
