require "rails_helper"

describe "Adm phase description placeholder", type: :request do
  let(:admin) { create(:administrator).user }
  let(:phase) { create(:proposal_phase) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  def placeholder_form
    get naming_adm_projekts_phase_path(phase)
    Nokogiri::HTML(response.body).css("form").find do |form|
      form.at_css("input[name=attribute][value=resource_form_description_placeholder]")
    end
  end

  it "edits the placeholder in a multi-line field" do
    form = placeholder_form

    expect(form.at_css("textarea[name$='[resource_form_description_placeholder]']")).to be_present
    expect(form.at_css("input[type=text][name$='[resource_form_description_placeholder]']")).to be_nil
  end

  it "saves line breaks" do
    form = placeholder_form
    field = form.at_css("textarea")["name"]
    params = form.css("input[type=hidden]").to_h { |input| [input["name"], input["value"]] }

    patch form["action"], params: params.merge(field => "Erste Zeile\r\nZweite Zeile"),
                          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(phase.reload.resource_form_description_placeholder).to eq "Erste Zeile\r\nZweite Zeile"
  end
end
