require "rails_helper"

describe MunicipalPlansHelper do
  describe "#municipal_plan_text" do
    def render(text)
      Nokogiri::HTML::DocumentFragment.parse(helper.municipal_plan_text(text))
    end

    it "renders the lines of an imported list as list items" do
      text = "– Gewerbe ansiedeln\n– Wohnungen bauen"

      expect(helper.municipal_plan_text(text))
        .to eq "<ul><li>Gewerbe ansiedeln</li><li>Wohnungen bauen</li></ul>"
    end

    it "accepts a hyphen, a bullet and an asterisk as marker" do
      expect(render("- eins\n• zwei\n* drei").css("ul > li").map(&:text)).to eq %w[eins zwei drei]
    end

    it "keeps the text before and after the list in its own paragraphs" do
      text = "Folgendes:\n- a\n- b\nDanach\nzweite Zeile"

      expect(helper.municipal_plan_text(text)).to eq(
        "<p>Folgendes:</p>\n\n<ul><li>a</li><li>b</li></ul>\n\n<p>Danach\n<br />zweite Zeile</p>"
      )
    end

    it "keeps the paragraphs around a list" do
      html = render("Das Plangebiet liegt am Stadtrand.\n\n– Gewerbe ansiedeln\n– Wohnen\n\nEnde")

      expect(html.children.select(&:element?).map(&:name)).to eq %w[p ul p]
      expect(html.css("p").map(&:text)).to eq ["Das Plangebiet liegt am Stadtrand.", "Ende"]
      expect(html.css("ul > li").map(&:text)).to eq ["Gewerbe ansiedeln", "Wohnen"]
    end

    it "renders text without bullets exactly as simple_format does" do
      texts = ["Erster Absatz\n\nZweiter Absatz", "Zeile eins\r\nZeile zwei", "1. eins\n2. zwei", "einfach"]

      texts.each do |text|
        expect(helper.municipal_plan_text(text)).to eq helper.simple_format(text)
      end
    end

    it "needs whitespace after the marker" do
      text = "-5 °C\n*Anmerkung\n–Text"

      expect(render(text).css("ul")).to be_empty
      expect(helper.municipal_plan_text(text)).to eq helper.simple_format(text)
    end

    it "filters markup in a list item the same way as in a paragraph" do
      html = render("Text <script>alert(1)</script> <b>fett</b>\n- <script>alert(2)</script> <b>fett</b>")

      expect(html.css("script")).to be_empty
      expect(html.at_css("p b").text).to eq "fett"
      expect(html.at_css("li b").text).to eq "fett"
    end

    it "renders nil and blank text as simple_format does" do
      [nil, "", "  "].each do |text|
        expect(helper.municipal_plan_text(text)).to eq helper.simple_format(text)
      end
    end
  end
end
