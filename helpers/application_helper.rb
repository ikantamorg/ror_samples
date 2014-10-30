module ApplicationHelper

  def title(title)
    content_for(:title) { title }
  end

  def stylesheet(file)
    content_for(:stylesheet) {
      stylesheet_link_tag(file, media: 'all')
    }
  end

  def javascript(*files)
    content_for(:javascript) {
      javascript_include_tag(*files)
    }
  end

  def devise_sign_in_error
    content_tag(:p, t('devise.failure.invalid'), class: 'alert') if flash[:alert].present?
  end

  def form_error_message(resource, field)
    if resource.errors[field].present?
      content_tag(:p, resource.errors[field].first, class: 'alert_error')
    end
  end

end
