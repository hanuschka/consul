require "rails_helper"

describe "CKEditor media library", type: :request do
  let(:managed_projekt) { create(:projekt) }
  let(:other_projekt) { create(:projekt) }
  let(:projekt_manager) do
    create(:projekt_manager).tap do |manager|
      create(:projekt_manager_assignment, :manage, projekt_manager: manager, projekt: managed_projekt)
    end
  end
  let(:manager_user) { projekt_manager.user }

  def create_image(title:, **attributes)
    AdminImage.new(title: title, **attributes).tap do |image|
      image.storage_data.attach(io: file_fixture("clippy.png").open,
                                filename: "clippy.png", content_type: "image/png")
      image.data_file_name = "clippy.png"
      image.save!
    end
  end

  def listed_titles
    get "/ckeditor/assets", params: { type: "picture" }, headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:ok)
    response.parsed_body["items"].map { |item| item["title"] }
  end

  let!(:own_upload) { create_image(title: "Own upload", user: manager_user) }
  let!(:managed_image) { create_image(title: "Managed projekt image", projekt: managed_projekt) }
  let!(:other_image) { create_image(title: "Other projekt image", projekt: other_projekt) }
  let!(:foreign_upload) { create_image(title: "Someone else's upload", user: create(:user)) }

  describe "a projekt manager" do
    before { login_as(manager_user) }

    it "lists their own uploads and the images of the projekts they manage" do
      expect(listed_titles).to contain_exactly("Own upload", "Managed projekt image")
    end

    it "can edit the alt text of an image they uploaded" do
      patch "/ckeditor/pictures/#{own_upload.id}",
            params: { picture: { alt_text: "Radweg vorher" } },
            headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(own_upload.reload.alt_text).to eq("Radweg vorher")
    end

    it "loses an image they uploaded to a projekt they no longer manage" do
      revoked_upload = create_image(title: "Upload to a revoked projekt",
                                    user: manager_user, projekt: other_projekt)

      expect(listed_titles).not_to include("Upload to a revoked projekt")

      delete "/ckeditor/pictures/#{revoked_upload.id}", headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:forbidden)
      expect(AdminImage.exists?(revoked_upload.id)).to be true
    end

    it "cannot edit an image of a projekt they do not manage" do
      patch "/ckeditor/pictures/#{other_image.id}",
            params: { picture: { alt_text: "Changed" } },
            headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:forbidden)
      expect(other_image.reload.alt_text).not_to eq("Changed")
    end
  end

  it "shows an administrator the whole library" do
    login_as(create(:administrator).user)

    expect(listed_titles).to contain_exactly(
      "Own upload", "Managed projekt image", "Other projekt image", "Someone else's upload"
    )
  end

  it "refuses the list to a regular user" do
    login_as(create(:user))

    get "/ckeditor/assets", params: { type: "picture" }, headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["error"]).to be_present
  end
end
