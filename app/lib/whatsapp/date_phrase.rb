module Whatsapp::DatePhrase
  DAYS_PER_MONTH = 30
  MONTHS_PER_YEAR = 12
  MAX_DAYS_NAMED = 31

  module_function

  # Every date that reaches a citizen — in the bot's own copy or through the
  # assistant's prose — is written here rather than at the call site, because
  # WhatsApp reads 13.08.2026 as a phone number, renders it tappable and offers
  # to place a call from it. A month spelled out cannot be read as one, so the
  # guarantee is the format rather than an instruction not to write digits.
  #
  # The assistant is handed both phrasings of the same date: the absolute one to
  # copy verbatim and the relative one to lead with. It has no clock and no
  # formatter of its own, so a date it never receives in digits is one it cannot
  # hand back in digits.
  def absolute(value)
    date = value&.to_date

    return if date.blank?

    I18n.l(date, format: I18n.t("whatsapp.bot.date.absolute_format"))
  end

  # For an event, where the time of day is half of what was asked.
  def absolute_with_time(value)
    return if value.blank?

    I18n.l(value.in_time_zone, format: I18n.t("whatsapp.bot.date.absolute_with_time_format"))
  end

  # Bucketed here rather than through distance_of_time_in_words, whose German is
  # nominative: wrapping its "5 Tage" in a "vor %{time}" line reads "vor 5
  # Tage". The dative belongs to the copy, so each unit is its own pluralised
  # key — the same shape the projekt countdowns use.
  #
  # Days up to a month, then months, then years: this dates something in a chat
  # message, where nothing turns on the difference between five and six weeks.
  def relative(value)
    date = value&.to_date

    return if date.blank?

    days = (date - Time.zone.today).to_i

    return I18n.t("whatsapp.bot.date.today") if days.zero?

    unit, count = bucket(days.abs)

    I18n.t("whatsapp.bot.date.#{days.negative? ? "past" : "future"}.#{unit}", count: count)
  end

  def bucket(days)
    return [:days, days] if days < MAX_DAYS_NAMED

    months = days / DAYS_PER_MONTH

    return [:months, months] if months < MONTHS_PER_YEAR

    [:years, months / MONTHS_PER_YEAR]
  end
  private_class_method :bucket
end
