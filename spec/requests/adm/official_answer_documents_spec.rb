require "rails_helper"

describe "Official answer documents in /adm", type: :request do
  let(:report) { create(:deficiency_report) }
  let(:officer) { create(:deficiency_report_officer) }
  let(:case_worker) { officer.user }

  def pdf
    fixture_file_upload("clippy.pdf", "application/pdf")
  end

  def save_answer(files: [pdf], answer: "Wird bearbeitet")
    params = { deficiency_report: { official_answer: answer } }
    params[:deficiency_report][:official_answer_documents] = files if files

    patch update_official_answer_adm_deficiency_reports_deficiency_report_path(report),
          params: params,
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def answer_form
    form = response.body[response.body.index("update_official_answer")..]
    form[..form.index("</form>")]
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    report.update!(responsible: officer)
  end

  describe "a case worker assigned to the report" do
    before { login_as(case_worker) }

    it "offers the add-document control inside the answer form" do
      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).to include("kern--form--nested-entries")
      expect(response.body).to include(I18n.t("components.kern.form.attachments_component.add"))
      expect(response.body).to include("enctype=\"multipart/form-data\"")
    end

    it "states the allowed types, the count and the size limit" do
      get adm_deficiency_reports_deficiency_report_path(report)

      hint = I18n.t("adm.deficiency_reports.deficiency_reports.show.official_answer_documents_hint",
                    types: Document.humanized_accepted_content_types,
                    size: Document.max_file_size,
                    count: DeficiencyReport.max_documents_allowed)

      expect(response.body).to include(hint.strip)
    end

    it "places the documents between the editor and the save button" do
      report.official_answer_documents.attach(pdf)

      get adm_deficiency_reports_deficiency_report_path(report)

      form = answer_form
      expect(form.index("ckeditor")).to be < form.index("adm-form-attachment")
      expect(form.index("adm-form-attachment")).to be <
        form.index(I18n.t("components.kern.form.attachments_component.add"))
      expect(form.index(I18n.t("components.kern.form.attachments_component.add"))).to be <
        form.index(I18n.t("shared.submit"))
    end

    it "lists a saved document with a download link and a remove control" do
      report.official_answer_documents.attach(pdf)

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(answer_form).to include("clippy.pdf")
      expect(answer_form).to include("remove_official_answer_document")
      expect(answer_form).to include("data-turbo-confirm")
    end

    it "offers no further upload slot once the limit is reached" do
      DeficiencyReport.max_documents_allowed.times { report.official_answer_documents.attach(pdf) }

      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).to include('nested-entries-max-value="0"')
    end

    it "saves the answer and the document with one submit" do
      expect { save_answer }.to change { report.reload.official_answer_documents.count }.by(1)

      expect(report.reload.official_answer).to include("Wird bearbeitet")
    end

    it "saves several documents with one submit" do
      expect { save_answer(files: [pdf, pdf]) }
        .to change { report.reload.official_answer_documents.count }.by(2)
    end

    it "keeps existing documents when the answer is saved again without choosing a file" do
      save_answer
      expect(report.reload.official_answer_documents.count).to eq(1)

      save_answer(files: nil, answer: "Aktualisierte Antwort")

      expect(report.reload.official_answer_documents.count).to eq(1)
      expect(report.official_answer).to include("Aktualisierte Antwort")
    end

    it "keeps existing documents when the file input is submitted empty" do
      save_answer
      save_answer(files: [""], answer: "Noch eine Antwort")

      expect(report.reload.official_answer_documents.count).to eq(1)
    end

    it "reports a file type the instance does not allow" do
      save_answer(files: [fixture_file_upload("clippy.png", "image/png")])

      expect(report.reload.official_answer_documents).not_to be_attached
      expect(response.body).to include("kern-alert--danger")
    end

    it "reports a file that exceeds the size limit" do
      allow(Document).to receive(:max_file_size).and_return(0)

      save_answer

      expect(report.reload.official_answer_documents).not_to be_attached
      expect(response.body).to include(
        I18n.t("deficiency_reports.official_answer_documents.too_large", size: 0)
      )
    end

    it "reports more documents than the instance allows" do
      allow(DeficiencyReport).to receive(:max_documents_allowed).and_return(1)
      report.official_answer_documents.attach(pdf)

      save_answer

      expect(report.reload.official_answer_documents.count).to eq(1)
      expect(response.body).to include(
        I18n.t("deficiency_reports.official_answer_documents.too_many", count: 1)
      )
    end

    it "names the problem without an untranslated attribute prefix" do
      save_answer(files: [fixture_file_upload("clippy.png", "image/png")])

      expect(response.body).to include(
        I18n.t("deficiency_reports.official_answer_documents.wrong_type",
               types: Document.humanized_accepted_content_types)
      )
      expect(response.body).not_to include("Official answer documents")
    end

    it "does not list a rejected document as if it were attached" do
      save_answer(files: [fixture_file_upload("clippy.png", "image/png")])

      expect(response.body).not_to include("clippy.png")
    end

    it "keeps a document that was already saved when a later upload is rejected" do
      save_answer
      save_answer(files: [fixture_file_upload("clippy.png", "image/png")])

      expect(report.reload.official_answer_documents.count).to eq(1)
      expect(response.body).to include("clippy.pdf")
    end

    it "can remove a document again" do
      save_answer
      attachment = report.reload.official_answer_documents.first

      delete remove_official_answer_document_adm_deficiency_reports_deficiency_report_path(
        report, attachment_id: attachment.id
      )

      expect(report.reload.official_answer_documents).not_to be_attached
    end
  end

  describe "an officer who may read but not administer the report" do
    let(:reader) { create(:deficiency_report_officer) }

    before do
      Setting["deficiency_reports.admins_must_assign_officer"] = true
      Setting["deficiency_reports.officers_see_all_reports"] = true
      report.official_answer_documents.attach(pdf)
      login_as(reader.user)
    end

    it "still sees the documents, without an editor or a remove control" do
      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).to include("clippy.pdf")
      expect(response.body).not_to include("remove_official_answer_document")
      expect(response.body).not_to include("kern--form--nested-entries")
    end
  end

  describe "someone who may not administer the report" do
    it "cannot attach a document" do
      login_as(create(:user))

      expect { save_answer }.not_to change { report.reload.official_answer_documents.count }
    end
  end

  describe "the published answer" do
    before { Setting["feature.deficiency_reports"] = true }

    it "links the attached document on the public page" do
      login_as(case_worker)
      save_answer

      get deficiency_report_path(report)

      expect(response.body).to include("clippy.pdf")
    end

    it "shows the answer section when there are documents but no answer text" do
      report.update!(official_answer: nil)
      report.official_answer_documents.attach(pdf)

      get deficiency_report_path(report)

      expect(response.body).to include(I18n.t("custom.deficiency_reports.show.official_answer.title"))
      expect(response.body).to include("clippy.pdf")
    end
  end
end
