module CustomHelper
  include HasEmbeddableShortcodes

  def tag_kind_name(kind)
    if kind == 'category'
      t('admin.tags.logic.category')
    end
  end

  def tag_count_label(tags)
    label = t('admin.tags.index.topic')
    label = label.pluralize if tags.count > 1
    label = label.downcase unless locale == :de
    label
  end

  def svg_tag(icon_name, options={})
    file = File.read(Rails.root.join('app', 'assets', 'images', 'custom', "#{icon_name}.svg"))
    doc = Nokogiri::HTML::DocumentFragment.parse file
    svg = doc.at_css 'svg'

    options.each {|attr, value| svg[attr.to_s] = value}

    doc.to_html.html_safe
  end

  def legislation_process_tabs(process)
    {
      "info"           => general_settings_adm_projekts_phase_path(process.projekt_phase),
      "draft_versions" => legislation_process_draft_versions_adm_projekts_phase_path(process.projekt_phase),
    }
  end

  def in_projekt_footer?
    params[:projekt_phase_id].present? && !request.path.starts_with?('/projekts')
  end

  def set_comments_view_context_variables(commentable, comment_order: nil)
    @commentable = commentable
    @comment_tree = CommentTree.new(@commentable, params[:page], comment_order)

    if @commentable.present?
      @comment_flags = set_comment_flags(@comment_tree.comments)
    end

    {
      commentable: @commentable,
      comment_tree: @comment_tree,
      comment_flags: @comment_flags
    }
  end

  def toggle_element_in_array(array, element)
    array ||= []

    if array.present? && !array.is_a?(Array)
      array = [array]
    end

    if array.include?(element)
      array.delete(element)
    else
      array.push(element)
    end

    array
  end

  def resource_show_url(resource)
    case resource
    when Proposal
      proposal_path(resource)
    when Debate
      debate_path(resource)
    end
  end

  def process_custom_content_if_needed(content, projekt: nil)
    return content if content.blank?

    new_content = content

    if projekt.present?
      new_content = process_shortcodes(new_content, projekt: projekt)
    end

    if Setting["extended_feature.gdpr.two_click_iframe_solution"].present? &&
        new_content&.include?("</iframe>")
      new_content = process_iframe_embeds(new_content)
    end

    new_content = process_oembeds(new_content)

    new_content
  end

  def process_iframe_embeds(content)
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    doc.css("iframe").each do |iframe|
      iframe["data-src"] = iframe["src"]
      iframe["src"] = ""
    end

    doc.to_html
  end

  def process_oembeds(content)
    if content&.exclude?("<oembed")
      return content
    end

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    doc.css("oembed").each do |oembed|
      url = oembed["url"]&.strip
      next unless url&.include?("youtube.com")

      rendered_html = Shared::ExternalVideoPlayer.new(url: url).render_in(view_context)
      fragment = Nokogiri::HTML::DocumentFragment.parse(rendered_html)

      p_node = Nokogiri::XML::Node.new('p', doc)
      fragment.children.each { |child| p_node.add_child(child.dup) }

      if (figure = oembed.ancestors("figure").first)
        figure.replace(p_node)
      end
    end

    doc.to_html
  end
end
