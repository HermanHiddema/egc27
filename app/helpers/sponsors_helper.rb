module SponsorsHelper
  # Keeps sponsor views aligned with the helper name referenced in PR notes while
  # delegating icon rendering to the shared application helper implementation.
  def sponsor_social_media_icon(platform, css_class: "w-5 h-5")
    social_media_icon(platform, css_class: css_class)
  end
end
