require "rails_helper"

describe "Image credits on a replaced file" do
  describe Image do
    let(:image) do
      image = create(:poll).build_image(user: create(:user), credits: "©Alter Fotograf")
      image.attachment.attach(io: file_fixture("clippy.jpg").open, filename: "clippy.jpg")
      image.save!(validate: false)
      image.reload
    end

    it "clears the credit when the file is replaced" do
      image.attachment = fixture_file_upload("clippy.png", "image/png")
      image.save!(validate: false)

      expect(image.reload.credits).to be_nil
    end

    it "keeps a credit given together with the new file" do
      image.attachment = fixture_file_upload("clippy.png", "image/png")
      image.credits = "©Neuer Fotograf"
      image.save!(validate: false)

      expect(image.reload.credits).to eq "©Neuer Fotograf"
    end

    it "keeps the credit when only other fields change" do
      image.update!(ai_generated: true)

      expect(image.reload.credits).to eq "©Alter Fotograf"
    end
  end

  describe SiteCustomization::Image do
    let(:image) do
      image = SiteCustomization::Image.create!(name: "header_image", credits: "©Alter Fotograf")
      image.image.attach(io: file_fixture("clippy.jpg").open, filename: "clippy.jpg")
      image.reload
    end

    it "clears the credit when the file is replaced" do
      image.image = fixture_file_upload("clippy.png", "image/png")
      image.save!(validate: false)

      expect(image.reload.credits).to be_nil
    end
  end
end
