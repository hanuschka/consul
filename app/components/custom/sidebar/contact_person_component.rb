# frozen_string_literal: true

class Sidebar::ContactPersonComponent < ApplicationComponent
  attr_reader :name, :role, :phone, :email

  def initialize(name: nil, role: nil, phone: nil, email: nil)
    @name = name
    @role = role
    @phone = phone
    @email = email
  end

  def render?
    [name, role, phone, email].any?(&:present?)
  end

  def heading_id
    @heading_id ||= "sidebar-contact-person-#{SecureRandom.hex(4)}"
  end

  def initials
    words = name.to_s.split
    names = words.reject { |word| word.end_with?(".") }.presence || words
    [names.first, (names.last if names.size > 1)].compact.map { |part| part[0] }.join.upcase
  end

  def phone_linkable?
    phone.match?(/\d/)
  end

  def phone_href
    "tel:#{phone.gsub(/[^0-9+]/, "")}"
  end

  def email_link_label
    name.present? ? t(".email_to_name", name: name) : t(".email")
  end
end
