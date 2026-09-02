require "rails_helper"

describe "Requesting a page by slug", type: :request do
  # An encoded slash collapses params[:id] to "/", and "/".split("/") is empty, so ActionView's
  # normalize_name used to call .empty? on nil and the request ended in a 500 (CON-2996).
  reaching_the_controller = {
    "an encoded slash, as sent by file scanners"  => "/%2f.mysql_history",
    "an encoded bare slash"                       => "/%2f",
    "a slug containing a space"                   => "/foo%20bar",
    "a scanner probing for another stack"         => "/wp-admin",
    "a well-formed slug with no page or template" => "/eine-seite-die-es-nicht-gibt"
  }

  reaching_the_controller.each do |description, path|
    it "answers 404 rather than 500 for #{description}" do
      get path

      expect(response).to have_http_status(:not_found)
    end
  end

  it "still renders a legitimate template id that contains a slash" do
    get "/help"

    expect(response).to have_http_status(:ok)
  end
end
