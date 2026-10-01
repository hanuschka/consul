require "rails_helper"

describe MailerHelper, "#mailer_inline_html", type: :helper do
  it "unwraps a single paragraph" do
    expect(helper.mailer_inline_html("<p>Leider nicht</p>")).to eq "Leider nicht"
  end

  it "joins multiple paragraphs with line breaks and keeps inline formatting" do
    html = "<p>Erster <strong>Absatz</strong></p>\n<p>Zweiter</p>"

    expect(helper.mailer_inline_html(html)).to eq "Erster <strong>Absatz</strong><br><br>Zweiter"
  end

  it "keeps non-paragraph blocks between paragraphs" do
    html = "<p>A</p><ul><li>x</li></ul><p>B</p>"

    expect(helper.mailer_inline_html(html)).to eq "A<br><br><ul><li>x</li></ul><br><br>B"
  end

  it "drops empty paragraphs" do
    expect(helper.mailer_inline_html("<p>A</p><p>&nbsp;</p><p></p><p>B</p>")).to eq "A<br><br>B"
  end

  it "removes unsafe markup" do
    result = helper.mailer_inline_html("<p>A<script>alert(1)</script></p>")

    expect(result).not_to include "<script>"
    expect(result).to start_with "A"
  end

  it "returns an empty string for blank input" do
    expect(helper.mailer_inline_html(nil)).to eq ""
    expect(helper.mailer_inline_html("")).to eq ""
  end

  it "returns an html_safe string" do
    expect(helper.mailer_inline_html("<p>A</p>")).to be_html_safe
  end
end
