class ProjektContentBlockTemplatesController < ApplicationController
  skip_authorization_check

  def index
    render Projekts::ContentBlockTemplatesSelectorContentComponent.new, layout: false
  end
end
