module Adm::Projekts::ImportChatsHelper
  # Redcarpet drops raw HTML and images before the sanitizer sees the output,
  # so a reply can only ever render as text and links.
  def import_chat_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      no_images: true,
      safe_links_only: true,
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: AiChatReplySanitizer::LINK_RELATION }
    )
    extensions = {
      autolink: true,
      fenced_code_blocks: true,
      lax_spacing: true,
      no_intra_emphasis: true,
      strikethrough: true,
      tables: true
    }

    AiChatReplySanitizer.new.sanitize(Redcarpet::Markdown.new(renderer, extensions).render(text))
  end

  def import_chat_proposal_description(proposal)
    details = proposal["details"] || {}

    case proposal["action"]
    when "remove_phase"
      name = details["name"].presence || ProjektImports::AiEditJournal.phase_label(details["type"])

      t("adm.projekts.imports.proposals.remove_phase", name: name)
    when "replace_content_blocks"
      t("adm.projekts.imports.proposals.replace_content_blocks", count: details["count"].to_i)
    else
      proposal["action"].to_s
    end
  end

  def import_chat_proposal_icon(proposal)
    case proposal["state"]
    when ProjektImports::AiEditJournal::APPLIED then "check_circle"
    when ProjektImports::AiEditJournal::DISCARDED then "block"
    else
      proposal["action"] == "remove_phase" ? "delete" : "view_agenda"
    end
  end
end
