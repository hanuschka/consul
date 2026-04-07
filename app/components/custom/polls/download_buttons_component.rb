class Polls::DownloadButtonsComponent < ApplicationComponent
  def initialize(poll:, path_helper:, path_params: {}, compact: true)
    @poll = poll
    @path_helper = path_helper
    @path_params = path_params
    @compact = compact
  end

  private

  attr_reader :poll, :path_helper, :path_params, :compact

  def button_class
    classes = ["button", "hollow"]
    classes << "-compact" if compact
    classes << "-no-margin" unless compact
    classes.join(" ")
  end

  def download_path(format)
    helpers.send(path_helper, poll, path_params.merge(format: format))
  end
end
