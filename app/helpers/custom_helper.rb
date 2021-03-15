module CustomHelper
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
end
