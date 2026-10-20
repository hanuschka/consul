require "rails_helper"

describe "Requesting a page by slug", type: :request do
  # An encoded slash collapses params[:id] to "/", and "/".split("/") is empty, so ActionView's
  # normalize_name used to call .empty? on nil and the request ended in a 500 (CON-2996).
  reaching_the_controller = {
    "an encoded slash, as sent by file scanners"  => "/%2f.mysql_history",
    "an encoded bare slash"                       => "/%2f",
    "a slug containing a space"                   => "/foo%20bar",
    "a scanner probing for another stack"         => "/wp-admin",
    "a well-formed slug with no page or template" => "/eine-seite-die-es-nicht-gibt",
    # A slug without a custom page used to render any template of that name, so internal ones
    # such as the forbidden page crashed on missing variables (CLI_ABST-8B).
    "the internal forbidden template"             => "/forbidden",
    "the internal custom page template"           => "/custom_page",
    "the internal new-design page template"       => "/custom_page_new",
    "the removed help page"                       => "/help"
  }

  reaching_the_controller.each do |description, path|
    it "answers 404 rather than 500 for #{description}" do
      get path

      expect(response).to have_http_status(:not_found)
    end
  end

  it "no longer routes the removed help subpages" do
    expect { get "/help/how-to-use" }.to raise_error(ActionController::RoutingError)
  end
end
