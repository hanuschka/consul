require "rails_helper"

describe "Newsletter block toolbar in text edit mode", type: :system do
  let(:admin) { create(:administrator).user }
  let(:newsletter) { create(:newsletter) }
  let(:paragraphs) { Array.new(30) { |i| "<p>Absatz #{i + 1}: Hier steht Ihr Text für den Newsletter.</p>" } }
  let(:words) { %w[Fett Kursiv Verlinkt].map { |word| "<p><span>#{word}</span></p>" } }

  before do
    create(:site_customization_content_block, :newsletter, newsletter: newsletter,
                                                           body: (words + paragraphs).join)
    login_as(admin)
  end

  def resize_window(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def enter_text_edit_mode
    visit edit_adm_newsletter_path(newsletter)
    find(".custom-content-block-wrapper").hover
    find(".js-edit-text-content-block").click
    expect(page).to have_css(".custom-content-block-wrapper.-simple-edit-mode")
  end

  def covered_toolbar_buttons
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".custom-content-block-wrapper.-in-edit-mode .custom-content-block--toolbar button"))
        .filter((button) => button.offsetParent !== null)
        .filter((button) => {
          const rect = button.getBoundingClientRect();
          const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
          return !hit || !(hit === button || button.contains(hit));
        })
        .map((button) => button.className)
    JS
  end

  def select_word(word)
    find(".custom-content-block-wrapper.-in-edit-mode .js-content-block span", exact_text: word).double_click
  end

  def edited_block
    find(".custom-content-block-wrapper.-in-edit-mode .js-content-block")
  end

  [[1280, 800], [1920, 1080]].each do |width, height|
    it "leaves every toolbar button uncovered on a #{width} px wide screen" do
      resize_window(width, height)

      enter_text_edit_mode

      expect(page).to have_css(".js-content-block-toggle-bold")
      expect(covered_toolbar_buttons).to be_empty
    end
  end

  it "keeps every toolbar button uncovered while scrolling through a long block" do
    resize_window(1280, 800)
    enter_text_edit_mode

    page.execute_script(<<~JS)
      document.querySelector(".custom-content-block-wrapper .js-content-block p:nth-of-type(20)")
        .scrollIntoView({ block: "center" });
    JS

    expect(covered_toolbar_buttons).to be_empty
  end

  it "applies bold, italic and a link to the selected text" do
    resize_window(1280, 800)
    enter_text_edit_mode

    select_word("Fett")
    find(".js-content-block-toggle-bold").click
    expect(edited_block).to have_css("strong", exact_text: "Fett")

    select_word("Kursiv")
    find(".js-content-block-toggle-italic").click
    expect(edited_block).to have_css("em", exact_text: "Kursiv")

    select_word("Verlinkt")
    find(".js-content-block-add-link").click
    find(".js-content-block-link-popup .js-content-block-url-input").set("https://example.org/mitmachen")
    find(".js-content-block-accept-link-edit").click
    expect(edited_block).to have_css("a[href='https://example.org/mitmachen']", text: "Verlinkt")
  end
end
