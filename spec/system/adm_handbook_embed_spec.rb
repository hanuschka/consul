require "rails_helper"

describe "Embedded manual in /adm", type: :system do
  let(:manual) { "http://localhost:9" }

  before do
    set_setting("handbook.url", manual)
    login_as(create(:administrator).user)
    page.driver.browser.manage.window.resize_to(1280, 900)
    visit adm_help_path(adm_section: "projekts")
    expect(page).to have_css("iframe.adm-embed__iframe", visible: :all)
  end

  def frame_height
    page.evaluate_script("document.querySelector('iframe.adm-embed__iframe').getBoundingClientRect().height")
  end

  def scroll_top
    page.evaluate_script("window.scrollY")
  end

  def load_manual_page
    page.execute_script("document.querySelector('iframe.adm-embed__iframe').dispatchEvent(new Event('load'))")
  end

  def send_from_manual(data, origin: manual)
    page.execute_script(<<~JS, data, origin)
      const frame = document.querySelector("iframe.adm-embed__iframe")
      window.dispatchEvent(new MessageEvent("message", { data: arguments[0], origin: arguments[1], source: frame.contentWindow }))
    JS
  end

  it "falls back to a fixed height that fits the window until the manual reports its height" do
    expect(frame_height).to be_within(2).of(page.evaluate_script("window.innerHeight") - 65)
  end

  it "takes the height the manual reports, so only the browser scrolls" do
    send_from_manual({ type: "dt-handbook:height", height: 4321.4 }, origin: "https://evil.example")
    expect(frame_height).to be < 1000

    send_from_manual({ type: "dt-handbook:height", height: 4321.4 })
    expect(frame_height).to eq 4322

    send_from_manual({ type: "dt-handbook:height", height: 1200 })
    expect(frame_height).to eq 1200
  end

  it "scrolls the main window to a position the manual names and back to the top on a new manual page" do
    send_from_manual({ type: "dt-handbook:height", height: 6000 })
    send_from_manual({ type: "dt-handbook:scroll", top: 3000 })

    frame_top = page.evaluate_script("document.querySelector('iframe.adm-embed__iframe').offsetTop")
    expect(scroll_top).to be_within(80).of(frame_top + 3000 - 65)

    2.times { load_manual_page }

    expect(scroll_top).to eq 0
  end
end
