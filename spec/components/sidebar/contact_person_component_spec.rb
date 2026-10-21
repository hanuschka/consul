require "rails_helper"

describe Sidebar::ContactPersonComponent, type: :component do
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  def key(name, **options)
    I18n.t("components.sidebar.contact_person_component.#{name}", **options)
  end

  it "is not rendered when every value is blank" do
    render_inline(Sidebar::ContactPersonComponent.new(name: "", role: nil, phone: " ", email: nil))

    expect(page).not_to have_css(".sidebar-contact-person")
  end

  it "labels the card with a heading for screen readers" do
    render_inline(Sidebar::ContactPersonComponent.new(role: "Team Stadtplanung"))

    expect(page).to have_css("section.sidebar-contact-person h2.show-for-sr", text: key("title"))
  end

  it "builds the initials from the first and last name, skipping titles" do
    render_inline(Sidebar::ContactPersonComponent.new(name: "Dr. Maria von Muster"))

    expect(page.find(".sidebar-contact-person--initials").text.strip).to eq "MM"
  end

  it "uses a single initial for a single name" do
    render_inline(Sidebar::ContactPersonComponent.new(name: "maria"))

    expect(page.find(".sidebar-contact-person--initials").text.strip).to eq "M"
  end

  it "shows a user icon without a name" do
    render_inline(Sidebar::ContactPersonComponent.new(email: "stadtplanung@jena.example"))

    expect(page).to have_css(".sidebar-contact-person--initials i.fa-user")
    expect(page).not_to have_css(".sidebar-contact-person--name")
  end

  it "links a phone number with digits only" do
    render_inline(Sidebar::ContactPersonComponent.new(phone: "+49 3641 49-0"))

    expect(page).to have_link "+49 3641 49-0", href: "tel:+493641490"

    render_inline(Sidebar::ContactPersonComponent.new(phone: "über die Zentrale"))

    expect(page).not_to have_css("a[href^='tel:']")
    expect(page).to have_text "über die Zentrale"
  end

  it "gives the e-mail link a name that stands on its own" do
    render_inline(Sidebar::ContactPersonComponent.new(name: "Maria Muster", email: "maria@jena.example"))

    expect(page).to have_link "#{key("email_to_name", name: "Maria Muster")} #{key("write")}",
                              href: "mailto:maria@jena.example", exact: true

    render_inline(Sidebar::ContactPersonComponent.new(email: "stadtplanung@jena.example"))

    expect(page).to have_link "#{key("email")} #{key("write")}", href: "mailto:stadtplanung@jena.example"
  end
end
