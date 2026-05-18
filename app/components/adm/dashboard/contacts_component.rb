class Adm::Dashboard::ContactsComponent < ApplicationComponent
  attr_reader :contacts

  def initialize(contacts:)
    @contacts = contacts
  end

  def render?
    contacts.any?
  end
end
