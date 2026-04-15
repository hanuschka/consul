class CsvJobs::UsersJob < ApplicationJob
  include Rails.application.routes.url_helpers

  queue_as :default

  def perform(exporting_user_id, users_to_export_ids, base_url)
    @exporting_user = User.find(exporting_user_id)
    users_to_export = User.where(id: users_to_export_ids).includes(:administrator, :moderator, :valuator, :manager, :poll_officer, :organization, registered_address: :registered_address_street)

    date = Date.current.iso8601
    dir = Rails.root.join("tmp/csv_exports")
    FileUtils.mkdir_p(dir)

    file_path = dir.join("users_#{exporting_user_id}_#{date}.csv")
    File.write(file_path, CsvServices::UsersExporter.call(users_to_export))

    download_url = "#{base_url}#{csv_download_adm_users_path(date: date)}"
    Mailer.csv_download_ready(@exporting_user, download_url).deliver_later
  end
end
