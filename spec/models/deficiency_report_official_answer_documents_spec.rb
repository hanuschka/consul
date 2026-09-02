require "rails_helper"

describe DeficiencyReport do
  let(:report) { create(:deficiency_report) }

  def pdf
    fixture_file_upload("clippy.pdf", "application/pdf")
  end

  def png
    fixture_file_upload("clippy.png", "image/png")
  end

  describe "official answer documents" do
    it "accepts a document of an allowed type" do
      expect(report.official_answer_documents.attach(pdf)).to be_truthy

      expect(report.reload.official_answer_documents).to be_attached
      expect(report.official_answer_documents.first.filename.to_s).to eq("clippy.pdf")
    end

    it "rejects a content type the instance does not allow" do
      expect(report.official_answer_documents.attach(png)).to be false

      expect(report.reload.official_answer_documents).not_to be_attached
    end

    it "rejects more documents than the instance allows" do
      allow(DeficiencyReport).to receive(:max_documents_allowed).and_return(1)
      report.official_answer_documents.attach(pdf)

      expect(report.official_answer_documents.attach(pdf)).to be false
      expect(report.reload.official_answer_documents.count).to eq(1)
    end

    it "stays separate from the documents the citizen uploaded" do
      report.official_answer_documents.attach(pdf)

      expect(report.reload.official_answer_documents.count).to eq(1)
      expect(report.documents).to be_empty
    end

    it "is removed when the report is destroyed" do
      report.official_answer_documents.attach(pdf)
      attachment_id = report.official_answer_documents.first.id

      report.really_destroy!

      expect(ActiveStorage::Attachment.where(id: attachment_id)).not_to exist
    end
  end
end
