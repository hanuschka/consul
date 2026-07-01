class ProjektImports::Builders::NotificationBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |n|
      next nil if n["title"].blank? || n["body"].blank?

      phase.projekt_notifications.create!(
        title: n["title"],
        body: n["body"]
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "notification(#{n['title']}): #{e.message}"
    end
  end
end
