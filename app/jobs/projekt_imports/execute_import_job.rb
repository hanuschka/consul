class ProjektImports::ExecuteImportJob < ApplicationJob
  queue_as :projekt_imports

  BANNER_ASPECT_RATIO = "16:9".freeze

  def perform(projekt_import_id)
    projekt_import = ProjektImport.find(projekt_import_id)
    projekt_import.update!(status: "submitting")

    resolve_result = ProjektImports::ResolveContentBlocksService.call(projekt_import: projekt_import)
    if !resolve_result.success?
      projekt_import.mark_failed!(resolve_result.error, stage: "resolve_content_blocks", details: resolve_result.error_details)
      return
    end

    create_result = ProjektImports::CreateProjektFromImportService.call(projekt_import: projekt_import)
    if !create_result.success?
      projekt_import.mark_failed!(create_result.error, stage: "create_projekt", details: create_result.error_details)
      return
    end

    projekt = create_result.data[:projekt]

    generate_image_if_requested(projekt_import, projekt)

    projekt_import.update!(status: "completed", error_message: nil)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ExecuteImportJob] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import_id, stage: "execute_import_job" }) if defined?(Sentry)
    pi = ProjektImport.find_by(id: projekt_import_id)
    pi&.mark_failed!(e.message, exception: e)
    raise
  end

  private

  def generate_image_if_requested(projekt_import, projekt)
    if !projekt_import.generate_image
      projekt_import.update!(image_status: "skipped")
      return
    end

    image_prompt = projekt_import.ai_result&.dig("image_prompt")

    if image_prompt.blank?
      projekt_import.update!(image_status: "skipped")
      return
    end

    projekt_import.update!(image_status: "running")

    response = DtApi::Client.new.ai.generate_image(prompt: image_prompt, aspect_ratio: BANNER_ASPECT_RATIO)

    if !response.success?
      projekt_import.update!(image_status: "failed", image_error: "DT image generation failed")
      projekt_import.add_warning!("image_generation: DT returned an error")
      return
    end

    base64 = response.parsed_response["image"]
    if base64.blank?
      projekt_import.update!(image_status: "failed", image_error: "DT returned no image")
      projekt_import.add_warning!("image_generation: DT returned no image")
      return
    end

    attach_image(projekt, base64)
    projekt_import.update!(image_status: "completed")
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ExecuteImportJob#generate_image] failed: #{e.message}")
    Sentry.capture_exception(e, level: :warning, extra: { projekt_import_id: projekt_import.id, stage: "image_generation" }) if defined?(Sentry)
    projekt_import.update!(image_status: "failed", image_error: e.message)
    projekt_import.add_warning!("image_generation: #{e.message}")
  end

  def attach_image(projekt, base64)
    page = projekt.page
    return if page.blank?

    file = Tempfile.new(["projekt_import_image", ".jpg"], binmode: true)

    begin
      file.write(Base64.decode64(base64))
      file.rewind

      image = page.image || ::Image.new(imageable: page)
      image.attachment = ActionDispatch::Http::UploadedFile.new(
        tempfile: file,
        filename: "projekt_#{projekt.id}_hero.jpg",
        type: "image/jpeg"
      )
      image.user = projekt.author
      image.save!
      page.association(:image).reset
    ensure
      file.close
      file.unlink
    end
  end
end
