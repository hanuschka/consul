require "rails_helper"

describe WYSIWYGSanitizer do
  subject(:sanitizer) { described_class.new }

  describe "#sanitize" do
    it "turns a bare e-mail address link target into a mailto link" do
      html = '<p><a href="info@example.org">info@example.org</a></p>'

      expect(sanitizer.sanitize(html)).to include('href="mailto:info@example.org"')
    end

    it "turns an e-mail address resolved against the platform host into a mailto link" do
      html = '<p><a href="https://machmit.example.org/info@example.org%20" target="_blank">Mail</a></p>'

      result = sanitizer.sanitize(html)

      expect(result).to include('href="mailto:info@example.org"')
      expect(result).to include('target="_blank"')
    end

    it "keeps mailto links unchanged" do
      html = '<p><a href="mailto:info@example.org?subject=Hallo">Mail</a></p>'

      expect(sanitizer.sanitize(html)).to include('href="mailto:info@example.org?subject=Hallo"')
    end

    it "keeps web links and links to platform pages unchanged" do
      html = '<p><a href="https://example.org/kontakt?ref=1#team" target="_blank">web</a> ' \
             '<a href="/projekts/1">page</a> <a href="#top">anchor</a> ' \
             '<a href="https://example.org/team/info@example.org">deep</a></p>'

      result = sanitizer.sanitize(html)

      expect(result).to include('href="https://example.org/kontakt?ref=1#team"')
      expect(result).to include('href="/projekts/1"')
      expect(result).to include('href="#top"')
      expect(result).to include('href="https://example.org/team/info@example.org"')
      expect(result).not_to include("mailto:")
    end

    it "returns html-safe output when a link was repaired" do
      html = '<p><a href="info@example.org">info@example.org</a></p>'

      expect(sanitizer.sanitize(html)).to be_html_safe
    end
  end

  describe "#stripped?" do
    it "does not count a repaired e-mail link as stripped content" do
      original = '<p><a href="info@example.org">info@example.org</a></p>'

      expect(sanitizer.stripped?(original, sanitizer.sanitize(original))).to be false
    end

    it "still detects removed markup" do
      original = '<p onclick="alert(1)"><a href="info@example.org">info@example.org</a></p>'

      expect(sanitizer.stripped?(original, sanitizer.sanitize(original))).to be true
    end
  end
end
