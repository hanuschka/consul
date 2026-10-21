require "rails_helper"

describe "Help texts on adm > Startseite" do
  image_keys = %w[header_image mobile_header_image logo_header logo_header_for_transparent]
                 .map { |name| "adm.attribute_editor.site_customization/image.#{name}_description" }
  video_keys = %w[header_video mobile_header_video]
                 .map { |name| "adm.attribute_editor.site_customization/video.#{name}_description" }
  setting_keys = %w[
    extended_option.general.homepage_navigation_link_color
    extended_option.general.city_name
    extended_option.general.subtitle
    extended_option.general.homepage_button_link
    welcomepage.usage_stats
    welcomepage.platform_activity
    welcomepage.projekt_search
  ].map { |key| "setting.#{key}_description" }
  landing_prefix = "adm.attribute_editor.site_customization/page.landing.landing_"
  landing_keys = %w[desktop_header_image desktop_header_video mobile_header_image mobile_header_video]
                   .map { |name| "#{landing_prefix}#{name}_description" }
  outdated = /470 × 246|80 × 80|1920 × 760|BundID|gegenseitig aus|mutually exclusive/

  homepage_keys = image_keys + video_keys + setting_keys

  def text(key, locale)
    I18n.t(key, locale: locale, default: nil).tap do |value|
      expect(value).to be_present, "no #{locale} text for #{key}"
    end
  end

  %i[de en].each do |locale|
    it "states no outdated format or behaviour in #{locale}" do
      (homepage_keys + landing_keys).each do |key|
        expect(text(key, locale)).not_to match(outdated), "#{locale} #{key}: #{text(key, locale)}"
      end
    end

    it "recommends the header formats rendered on the homepage in #{locale}" do
      desktop = [image_keys[0], video_keys[0]] + landing_keys.first(2)
      mobile = [image_keys[1], video_keys[1]] + landing_keys.last(2)

      desktop.each { |key| expect(text(key, locale)).to include "1920 × 700" }
      mobile.each { |key| expect(text(key, locale)).to include "1080 × 1450" }
    end
  end

  it "gives the same figures in German and English" do
    homepage_keys.each do |key|
      expect(text(key, :en).scan(/\d+/).sort).to eq(text(key, :de).scan(/\d+/).sort), key
    end
  end
end
