class CsvJobs::CommentsJob < ApplicationJob
  queue_as :default

  def perform(exporting_user_id, comments_to_export_ids, commentable_name)
    @exporting_user = User.find(exporting_user_id)
    comments_to_export = Comment.where(id: comments_to_export_ids)

    file_name = "#{commentable_name}_comments_#{Time.zone.now.strftime("%Y-%m-%d-%H:%M")}.csv"
    file_path = "tmp/#{file_name}"
    File.write(Rails.root.join(file_path), CsvServices::CommentsExporter.call(comments_to_export))

    Mailer.file_ready(@exporting_user, file_name, file_path).deliver_later
  end
end
