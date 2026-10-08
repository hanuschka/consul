require "rails_helper"

describe "Saved content blocks in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:projekt_manager) { managing_manager }
  let(:other_projekt_manager) { managing_manager }
  let(:reviewing_manager) do
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, :review, projekt_manager: manager, projekt: create(:projekt))
    manager.user
  end
  let(:citizen) { create(:user) }

  def managing_manager
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, :manage, projekt_manager: manager, projekt: create(:projekt))
    manager.user
  end

  def create_block(user_specific:, content: "<p>Neue Vorlage</p>")
    post adm_saved_content_blocks_path, params: {
      saved_content_block: { content: content, context: "projekt", user_specific: user_specific }
    }
  end

  def update_block(block, content: "<p>Geänderte Vorlage</p>")
    patch adm_saved_content_block_path(block), params: {
      saved_content_block: { content: content }
    }
  end

  describe "a projekt manager" do
    before { login_as(projekt_manager) }

    it "creates an own template" do
      create_block(user_specific: "true")

      expect(response).to have_http_status(:created)
      expect(SavedContentBlock.last.user).to eq(projekt_manager)
    end

    it "creates an internal template" do
      create_block(user_specific: "false")

      expect(response).to have_http_status(:created)
      expect(SavedContentBlock.last.user).to be_nil
    end

    it "edits an own template" do
      block = create(:saved_content_block, user: projekt_manager)

      update_block(block)

      expect(response).to have_http_status(:ok)
      expect(block.reload.content).to include("Geänderte Vorlage")
    end

    it "deletes an own template" do
      block = create(:saved_content_block, user: projekt_manager)

      expect { delete adm_saved_content_block_path(block) }
        .to change(SavedContentBlock, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "edits an internal template" do
      block = create(:saved_content_block)

      update_block(block)

      expect(response).to have_http_status(:ok)
      expect(block.reload.content).to include("Geänderte Vorlage")
    end

    it "deletes an internal template" do
      block = create(:saved_content_block)

      expect { delete adm_saved_content_block_path(block) }
        .to change(SavedContentBlock, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "cannot edit another user's own template" do
      block = create(:saved_content_block, user: other_projekt_manager, content: "<p>Fremd</p>")

      update_block(block)

      expect(response).to redirect_to(root_path)
      expect(block.reload.content).to include("Fremd")
    end

    it "cannot delete another user's own template" do
      block = create(:saved_content_block, user: other_projekt_manager)

      expect { delete adm_saved_content_block_path(block) }
        .not_to change(SavedContentBlock, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "an administrator" do
    before { login_as(admin) }

    it "creates an internal template" do
      create_block(user_specific: "false")

      expect(response).to have_http_status(:created)
      expect(SavedContentBlock.last.user).to be_nil
    end

    it "edits another user's own template" do
      block = create(:saved_content_block, user: projekt_manager)

      update_block(block)

      expect(response).to have_http_status(:ok)
      expect(block.reload.content).to include("Geänderte Vorlage")
    end
  end

  describe "a projekt manager without the manage permission" do
    before { login_as(reviewing_manager) }

    it "cannot create a template" do
      expect { create_block(user_specific: "true") }
        .not_to change(SavedContentBlock, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "a citizen" do
    before { login_as(citizen) }

    it "cannot create a template" do
      expect { create_block(user_specific: "true") }
        .not_to change(SavedContentBlock, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
