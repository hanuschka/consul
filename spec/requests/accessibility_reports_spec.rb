require "rails_helper"

describe "Barriere melden", type: :request do
  let!(:barrier_page) do
    SiteCustomization::Page.create!(slug: "accessibility_report", footer_key: "accessibility_report",
                                    status: "published", title: "Barriere melden")
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    Setting["accessibility_report.recipient_email"] = "barrieren@stadt.example"
  end

  def submit(attributes)
    post accessibility_reports_path, params: { accessibility_report: attributes }
  end

  it "takes a report from a visitor who only filled the description" do
    expect { submit(description: "Kontrast zu gering") }
      .to have_enqueued_mail(AccessibilityReportMailer, :report_submitted)
      .with(hash_including("description" => "Kontrast zu gering"))

    expect(response).to redirect_to(page_path(barrier_page.slug))
  end

  it "confirms the report only to a reporter who left an address" do
    expect { submit(description: "Kontrast zu gering", email: "kai@example.org") }
      .to have_enqueued_mail(AccessibilityReportMailer, :confirmation)
    expect { submit(description: "Kontrast zu gering") }
      .not_to have_enqueued_mail(AccessibilityReportMailer, :confirmation)
  end

  it "keeps the input when the description is missing" do
    expect { submit(location: "/projekts/radweg", description: "") }
      .not_to have_enqueued_mail(AccessibilityReportMailer)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Nokogiri::HTML(response.body).at_css("#accessibility_report_location")["value"]).to eq "/projekts/radweg"
  end

  it "lists the page in the footer only once it is published" do
    accessibility_page = SiteCustomization::Page.find_by!(footer_key: "accessibility")
    accessibility_page.update!(status: "published")
    footer_link = "footer a[href='#{page_path(barrier_page.slug)}']"

    get page_path(accessibility_page.slug)
    expect(Nokogiri::HTML(response.body).at_css(footer_link)).to be_present

    barrier_page.update!(status: "draft")

    get page_path(accessibility_page.slug)
    expect(Nokogiri::HTML(response.body).at_css(footer_link)).to be_nil
  end
end
