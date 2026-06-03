class MasterportalDestroyCollectionJob < ApplicationJob
  queue_as :default

  def perform(masterportal_collection_id:)
    collection = MasterportalCollection.find_by(id: masterportal_collection_id)
    return if collection.nil?

    Masterportal::DestroyCollectionService.call(masterportal_collection: collection)
  end
end
