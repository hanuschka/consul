require "rails_helper"

describe Whatsapp::Send do
  # What the irreversible tools read back to answer "did we ask them this". The
  # publishing pill's id carries the version of the preview it stood under, and
  # PublishDraft asks about the bare action — recorded with its version, the
  # pill under every preview would have read as never offered.
  describe "the offers it remembers" do
    def remembered(*ids)
      Whatsapp::Send.send(:irreversible_ids, ids.map { |id| { id: id } })
    end

    it "remembers a publishing pill without the version it stood under" do
      expect(remembered("whatsapp_flow_draft_publish-a1b2c3d4e5f6")).to eq(["draft_publish"])
    end

    it "remembers a posting pill without the version it stood under" do
      expect(remembered("whatsapp_flow_comment_post-0f0e0d0c0b0a")).to eq(["comment_post"])
    end

    it "still remembers an untagged publishing pill" do
      expect(remembered("whatsapp_flow_draft_publish")).to eq(["draft_publish"])
    end

    it "remembers nothing that is not irreversible" do
      expect(remembered("whatsapp_flow_draft_revise")).to be_empty
    end
  end
end
