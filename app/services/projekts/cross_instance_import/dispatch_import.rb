class Projekts::CrossInstanceImport::DispatchImport < ApplicationService
  def initialize(source_url:, user:)
    @source_url = source_url
    @user = user
  end

  # The draft is created empty and inactive before the job starts, so the admin
  # gets a row to watch immediately and the import status has a record of its
  # own to live on. It reuses copy_status: an import is a copy that came from
  # somewhere else, and the badge, the stale detection and the screens that
  # hide an unfinished projekt all already read that column.
  #
  # The name is a stand-in -- the real one arrives with the bundle. parent_id
  # stays null: an imported projekt has no place in this instance's hierarchy
  # until the admin gives it one.
  def call
    projekt = Projekt.create!(
      name: I18n.t("adm.projekts.projekts.instance_import.pending_name"),
      author: user,
      parent_id: nil,
      activated: false,
      copy_status: "processing"
    )

    Projekts::CrossInstanceImport::ImportJob.perform_later(projekt.id, source_url)

    ServiceResult.success(projekt: projekt)
  end

  private

    attr_reader :source_url, :user
end
