class ProjektImports::Builders::EventBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |event|
      next nil if event["title"].blank? || event["datetime"].blank?

      phase.projekt_events.create!(
        title: event["title"],
        description: event["description"],
        datetime: event["datetime"],
        end_datetime: event["end_datetime"],
        location: event["location"],
        weblink: event["weblink"]
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "event(#{event['title']}): #{e.message}"
    end
  end
end
