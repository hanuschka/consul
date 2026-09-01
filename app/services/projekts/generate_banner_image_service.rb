class Projekts::GenerateBannerImageService < ApplicationService
  BANNER_ASPECT_RATIO = "16:9".freeze
  MAX_CONTEXT_LENGTH = 4000

  class GenerationFailedError < StandardError; end

  def initialize(projekt:, user:, user_prompt: nil, use_projekt_content: true)
    @projekt = projekt
    @user = user
    @user_prompt = user_prompt
    @use_projekt_content = use_projekt_content
  end

  def call
    image_prompt = build_image_prompt

    if image_prompt.blank?
      raise GenerationFailedError, "Image prompt generation returned no prompt"
    end

    response = DtApi::Client.new.ai.generate_image(
      prompt: image_prompt,
      aspect_ratio: BANNER_ASPECT_RATIO
    )

    if !response.success?
      raise GenerationFailedError, "DT image generation failed with status #{response.code}"
    end

    base64_image = response.parsed_response["image"]

    if base64_image.blank?
      raise GenerationFailedError, "DT returned no image"
    end

    attach_image(base64_image, response.parsed_response)
  end

  private

    def build_image_prompt
      Ai::RubyLlmFactory
        .chat(feature: "projekts.banner_image_prompt")
        .with_instructions(prompt_instructions)
        .ask(projekt_context)
        .content
        .to_s
        .strip
    end

    def prompt_instructions
      <<~TEXT.squish
        You write a single English prompt for an AI image generator that
        creates a photorealistic, wide-format banner image for a citizen
        participation projekt.
        When the input contains an "EDITOR IMAGE REQUEST", that request has
        the highest priority and defines the image subject: the resulting
        image MUST depict exactly what it asks for. Use the projekt title,
        subtitle and background only as supporting context for style, place
        and mood, and never let them override the editor request.
        When there is no editor request, base the image on the projekt title,
        subtitle and background instead.
        The image must not contain any text, letters, logos or watermarks.
        Respond with the image prompt only, without quotes or explanations.
      TEXT
    end

    def projekt_context
      page = @projekt.page
      parts = []

      if @user_prompt.present?
        parts << "EDITOR IMAGE REQUEST (highest priority, must be followed): #{@user_prompt}"
      end

      parts << "Projekt title: #{page&.title.presence || @projekt.name}"
      parts << "Projekt subtitle: #{strip_html(page&.subtitle)}"

      content_text = content_blocks_text

      if @use_projekt_content && content_text.present?
        parts << "Projekt background (context only): #{content_text.truncate(MAX_CONTEXT_LENGTH)}"
      end

      parts.join("\n")
    end

    def content_blocks_text
      strip_html(@projekt.content_blocks_body)
    end

    def strip_html(text)
      ActionController::Base.helpers.strip_tags(text.to_s).squish
    end

    def attach_image(base64_image, response_body)
      result = ::Projekts::AttachPageImageService.call(
        projekt: @projekt,
        user: @user,
        data: Base64.decode64(base64_image),
        filename: "projekt_#{@projekt.id}_ai_banner.jpg",
        content_type: "image/jpeg",
        ai_generated: true,
        ai_system: ::DtApi::Resources::Ai.reported_provider(response_body),
        ai_system_version: ::DtApi::Resources::Ai.reported_model(response_body)
      )

      if !result.success?
        raise GenerationFailedError, result.error
      end

      result.data[:image]
    end
end
