class Kern::Form::DocumentsComponent < ApplicationComponent
  def initialize(form:, show_hint: true)
    @form = form
    @show_hint = show_hint
  end

  private

    def documentable
      @form.object
    end

    def documents
      documentable.documents
    end

    def max_documents_allowed
      documentable.class.max_documents_allowed
    end

    def accepted_content_types
      documentable.class.accepted_content_types
    end

    def accepted_content_types_humanized
      Document.humanized_accepted_content_types
    end

    def max_file_size
      documentable.class.max_file_size
    end
end
