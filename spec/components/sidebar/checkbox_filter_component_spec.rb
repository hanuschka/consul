require "rails_helper"

describe Sidebar::CheckboxFilterComponent, type: :component do
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  let(:options) { [["Stadtentwicklung", 1], ["Bildung", 2]] }

  def render_filter(params: {}, **attributes)
    allow(vc_test_controller).to receive(:params)
      .and_return(ActionController::Parameters.new(params))

    render_inline(Sidebar::CheckboxFilterComponent.new(identifier: :topics, options: options, title: "Thema",
                                                       icon: "tags", id_prefix: "filter_topic", **attributes))
  end

  it "renders one checkbox per option under the identifier" do
    render_filter

    expect(page).to have_css("input[type=checkbox][name='topics[]']", count: 2)
    expect(page).to have_css("#filter_topic_1.js-sidebar-checkbox-filter[value='1']")
    expect(page).to have_css("ul[data-identifier='topics']")
  end

  it "checks and highlights the options given in the params" do
    render_filter(params: { topics: ["2"] })

    expect(page).to have_css("#filter_topic_2[checked]")
    expect(page).not_to have_css("#filter_topic_1[checked]")
    expect(page).to have_css("li.selected-option", count: 1, text: "Bildung")
  end

  it "groups the options in a fieldset described by the reload note" do
    render_filter

    fieldset = page.find("fieldset")
    note = page.find("##{fieldset["aria-describedby"]}", visible: :all)

    expect(fieldset).to have_css("legend", text: "Thema", visible: :all)
    expect(note.text(:all)).to eq I18n.t("custom.sidebar_filter.checkbox.updates_on_change")
  end

  it "shows the empty text when there are no options" do
    render_inline(Sidebar::CheckboxFilterComponent.new(identifier: :topics, options: [], title: "Thema",
                                                       icon: "tags", id_prefix: "filter_topic",
                                                       empty_text: "Keine Themen"))

    expect(page).to have_text("Keine Themen")
    expect(page).not_to have_css("input[type=checkbox]")
  end

  it "renders nothing without options or empty text" do
    render_inline(Sidebar::CheckboxFilterComponent.new(identifier: :topics, options: [], title: "Thema",
                                                       icon: "tags", id_prefix: "filter_topic"))

    expect(page).not_to have_css("input")
    expect(page).not_to have_text("Keine Themen")
  end
end
