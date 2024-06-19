class CsvJobs::UsersJob < ApplicationJob
  queue_as :default

  def perform(exporting_user_id, users_to_export_ids)
    @exporting_user = User.find(exporting_user_id)
    users_to_export = User.where(id: users_to_export_ids)
    file_name = "users_#{Time.zone.now.strftime("%Y-%m-%d-%H:%M")}.csv"
    file_path = "tmp/#{file_name}"

    File.write(Rails.root.join(file_path), CsvServices::UsersExporter.call(users_to_export))

    Mailer.file_ready(@exporting_user, file_name, file_path).deliver_later
  end
end
