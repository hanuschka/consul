# Snapshot of the demokratie.today content block template library, taken from
# production on 2026-09-10. The app no longer fetches templates over the DT
# API: a slow response there used to race the selector's request timeout and
# leave editors with an error instead of a template list.
#
# Ids are DT's own and must stay stable — anchor_template_id and
# category_hint are matched against them.
#
# Template bodies live beside this file under
# app/views/custom/projekts/dt_content_block_templates/, one file per
# template, named <id>_<slug>.html.
module ContentBlockTemplates::Manifest
  CATEGORIES = [
    {
      id: 1,
      name_de: "Basis",
      name_en: "Basics",
      section: "general",
      position: 1,
      directory: "basics",
      templates: [
        {
          id: 4,
          name: "text-plain",
          description: "Plain text block without heading. For paragraphs, explanations, and supplementary content.",
          position: 1,
          hidden: false,
          hidden_until: nil,
          file: "basics/4_text_plain.html"
        },
        {
          id: 25,
          name: "text-heading",
          description: "Heading with optional subtitle. For section titles and introductions.",
          position: 2,
          hidden: false,
          hidden_until: nil,
          file: "basics/25_text_heading.html"
        },
        {
          id: 27,
          name: "text-columns",
          description: "Text split into multiple columns. For side-by-side content and structured overviews.",
          position: 3,
          hidden: false,
          hidden_until: nil,
          file: "basics/27_text_columns.html"
        },
        {
          id: 26,
          name: "text-highlight",
          description: "Highlighted text section with visual emphasis. For key messages and important notices.",
          position: 4,
          hidden: false,
          hidden_until: nil,
          file: "basics/26_text_highlight.html"
        },
        {
          id: 7,
          name: "text-list",
          description: "Bulleted or numbered list. For enumerations, checklists, and structured points.",
          position: 5,
          hidden: false,
          hidden_until: nil,
          file: "basics/7_text_list.html"
        },
        {
          id: 8,
          name: "callout-border",
          description: "Callout box with colored border. For tips, notes, and highlighted information.",
          position: 6,
          hidden: false,
          hidden_until: nil,
          file: "basics/8_callout_border.html"
        },
        {
          id: 9,
          name: "callout-dark",
          description: "Callout box with dark background. For important announcements and standout messages.",
          position: 7,
          hidden: false,
          hidden_until: nil,
          file: "basics/9_callout_dark.html"
        },
        {
          id: 73,
          name: "callout-cards",
          description: "Multiple callout cards in a grid. For key facts, feature highlights, or benefit overviews.",
          position: 8,
          hidden: false,
          hidden_until: nil,
          file: "basics/73_callout_cards.html"
        }
      ]
    },
    {
      id: 2,
      name_de: "Hero",
      name_en: "Hero",
      section: "general",
      position: 2,
      directory: "hero",
      templates: [
        {
          id: 74,
          name: "hero-gradient",
          description: "Hero section with gradient background. For project introductions and page openers.",
          position: 1,
          hidden: false,
          hidden_until: nil,
          file: "hero/74_hero_gradient.html"
        },
        {
          id: 75,
          name: "hero-image-overlay",
          description: "Hero with background image and text overlay. For visually striking project headers.",
          position: 2,
          hidden: false,
          hidden_until: nil,
          file: "hero/75_hero_image_overlay.html"
        },
        {
          id: 76,
          name: "hero-split-image",
          description: "Hero with image and text side by side. For balanced introductions with visual context.",
          position: 3,
          hidden: false,
          hidden_until: nil,
          file: "hero/76_hero_split_image.html"
        },
        {
          id: 77,
          name: "hero-minimal",
          description: "Minimalist hero with clean typography. For simple, elegant project headers.",
          position: 4,
          hidden: false,
          hidden_until: nil,
          file: "hero/77_hero_minimal.html"
        },
        {
          id: 78,
          name: "hero-progress",
          description: "Hero with progress indicator. For projects with phases or timelines to show current status.",
          position: 5,
          hidden: false,
          hidden_until: nil,
          file: "hero/78_hero_progress.html"
        },
        {
          id: 79,
          name: "hero-slider",
          description: "Hero with image slider. For showcasing multiple visuals in the header area.",
          position: 6,
          hidden: false,
          hidden_until: nil,
          file: "hero/79_hero_slider.html"
        },
        {
          id: 80,
          name: "hero-split-left",
          description: "Hero with text on the left side. For left-aligned introductions with right-side visual.",
          position: 7,
          hidden: false,
          hidden_until: nil,
          file: "hero/80_hero_split_left.html"
        },
        {
          id: 81,
          name: "hero-stats",
          description: "Hero with key statistics. For project headers that highlight participation numbers or results.",
          position: 8,
          hidden: false,
          hidden_until: nil,
          file: "hero/81_hero_stats.html"
        },
        {
          id: 82,
          name: "hero-cards",
          description: "Hero with information cards below. For introductions that link to key topics or sections.",
          position: 9,
          hidden: false,
          hidden_until: nil,
          file: "hero/82_hero_cards.html"
        },
        {
          id: 83,
          name: "hero-video",
          description: "Hero with embedded video. For project headers featuring an introductory or explanatory video.",
          position: 10,
          hidden: false,
          hidden_until: nil,
          file: "hero/83_hero_video.html"
        }
      ]
    },
    {
      id: 3,
      name_de: "Media",
      name_en: "Media",
      section: "general",
      position: 3,
      directory: "media",
      templates: [
        {
          id: 84,
          name: "image-single",
          description: "Single image with optional caption. For photos, maps, or visual highlights.",
          position: 1,
          hidden: false,
          hidden_until: nil,
          file: "media/84_image_single.html"
        },
        {
          id: 85,
          name: "gallery-2col",
          description: "Image gallery in two columns. For before/after comparisons or paired visuals.",
          position: 2,
          hidden: false,
          hidden_until: nil,
          file: "media/85_gallery_2col.html"
        },
        {
          id: 86,
          name: "gallery-3col",
          description: "Image gallery in three columns. For showcasing multiple impressions or project photos.",
          position: 3,
          hidden: false,
          hidden_until: nil,
          file: "media/86_gallery_3col.html"
        },
        {
          id: 87,
          name: "gallery-hero-2",
          description: "Large hero image with two smaller images below. For featured visuals with supporting context.",
          position: 4,
          hidden: false,
          hidden_until: nil,
          file: "media/87_gallery_hero_2.html"
        },
        {
          id: 88,
          name: "gallery-4col",
          description: "Image gallery in four columns. For compact image overviews and photo collections.",
          position: 5,
          hidden: false,
          hidden_until: nil,
          file: "media/88_gallery_4col.html"
        },
        {
          id: 89,
          name: "gallery-2-4",
          description: "Mixed gallery with two large and four small images. For varied visual layouts.",
          position: 6,
          hidden: false,
          hidden_until: nil,
          file: "media/89_gallery_2_4.html"
        },
        {
          id: 90,
          name: "slider-fullwidth",
          description: "Full-width image slider. For immersive photo presentations and project impressions.",
          position: 7,
          hidden: false,
          hidden_until: nil,
          file: "media/90_slider_fullwidth.html"
        },
        {
          id: 91,
          name: "slider-peek",
          description: "Image slider with peek at next slides. For browseable galleries with visual continuity.",
          position: 8,
          hidden: true,
          hidden_until: nil,
          file: "media/91_slider_peek.html"
        },
        {
          id: 92,
          name: "slider-captions",
          description: "Image slider with text captions. For annotated photo galleries and documented impressions.",
          position: 9,
          hidden: false,
          hidden_until: nil,
          file: "media/92_slider_captions.html"
        },
        {
          id: 93,
          name: "slider-thumbnails",
          description: "Image slider with thumbnail navigation. For galleries where users can jump to specific images.",
          position: 10,
          hidden: true,
          hidden_until: nil,
          file: "media/93_slider_thumbnails.html"
        },
        {
          id: 130,
          name: "slider-fullwidth",
          description: "Full-width image slider with caption bar and dot navigation. Best for hero sections and phase highlights.",
          position: 11,
          hidden: true,
          hidden_until: nil,
          file: "media/130_slider_fullwidth.html"
        }
      ]
    },
    {
      id: 4,
      name_de: "Layout",
      name_en: "Layout",
      section: "general",
      position: 4,
      directory: "layout",
      templates: [
        {
          id: 94,
          name: "text-text",
          description: "Two text blocks side by side. For parallel content, comparisons, or dual perspectives.",
          position: 1,
          hidden: false,
          hidden_until: nil,
          file: "layout/94_text_text.html"
        },
        {
          id: 96,
          name: "list-explanations",
          description: "List with detailed explanations per item. For glossaries, term definitions, or feature descriptions.",
          position: 2,
          hidden: false,
          hidden_until: nil,
          file: "layout/96_list_explanations.html"
        },
        {
          id: 97,
          name: "stats-text",
          description: "Key statistics alongside explanatory text. For combining numbers with narrative context.",
          position: 3,
          hidden: false,
          hidden_until: nil,
          file: "layout/97_stats_text.html"
        },
        {
          id: 98,
          name: "icon-cards",
          description: "Numbered cards in a 2x2 grid with icons. For participation steps, features, or process overviews.",
          position: 4,
          hidden: false,
          hidden_until: nil,
          file: "layout/98_icon_cards.html"
        },
        {
          id: 99,
          name: "quote-context",
          description: "Quote with contextual information. For citizen testimonials, expert statements, or official quotes.",
          position: 5,
          hidden: false,
          hidden_until: nil,
          file: "layout/99_quote_context.html"
        },
        {
          id: 100,
          name: "image-left",
          description: "Image on the left, text on the right. For content sections with left-aligned visuals.",
          position: 6,
          hidden: false,
          hidden_until: nil,
          file: "layout/100_image_left.html"
        },
        {
          id: 101,
          name: "image-right",
          description: "Image on the right, text on the left. For content sections with right-aligned visuals.",
          position: 7,
          hidden: false,
          hidden_until: nil,
          file: "layout/101_image_right.html"
        },
        {
          id: 102,
          name: "portrait-cards",
          description: "Portrait cards with photo, name, and role. For team introductions and contact persons.",
          position: 8,
          hidden: false,
          hidden_until: nil,
          file: "layout/102_portrait_cards.html"
        },
        {
          id: 103,
          name: "fullwidth-overlay",
          description: "Full-width image with text overlay. For dramatic visual sections with messaging.",
          position: 9,
          hidden: false,
          hidden_until: nil,
          file: "layout/103_fullwidth_overlay.html"
        },
        {
          id: 95,
          name: "image-text",
          description: "Image paired with text. For illustrated explanations and visual storytelling.",
          position: 18,
          hidden: false,
          hidden_until: nil,
          file: "layout/95_image_text.html"
        }
      ]
    },
    {
      id: 6,
      name_de: "Daten",
      name_en: "Data",
      section: "general",
      position: 5,
      directory: "data",
      templates: [
        {
          id: 109,
          name: "process-icons",
          description: "Process steps with icons. For visually guided workflows and method explanations.",
          position: 1,
          hidden: false,
          hidden_until: nil,
          file: "data/109_process_icons.html"
        },
        {
          id: 108,
          name: "process-cards",
          description: "Process steps as individual cards. For visually separated workflow stages.",
          position: 2,
          hidden: false,
          hidden_until: nil,
          file: "data/108_process_cards.html"
        },
        {
          id: 104,
          name: "timeline-vertical",
          description: "Vertical timeline with dated entries. For project histories, phase overviews, and chronological events.",
          position: 3,
          hidden: false,
          hidden_until: nil,
          file: "data/104_timeline_vertical.html"
        },
        {
          id: 107,
          name: "process-numbered",
          description: "Numbered process steps in sequence. For how-to guides and participation instructions.",
          position: 4,
          hidden: false,
          hidden_until: nil,
          file: "data/107_process_numbered.html"
        },
        {
          id: 106,
          name: "milestone-cards",
          description: "Milestone cards with dates and descriptions. For project achievements and progress tracking.",
          position: 5,
          hidden: false,
          hidden_until: nil,
          file: "data/106_milestone_cards.html"
        },
        {
          id: 105,
          name: "steps-horizontal",
          description: "Horizontal step indicator. For process flows, participation phases, and sequential workflows.",
          position: 6,
          hidden: false,
          hidden_until: nil,
          file: "data/105_steps_horizontal.html"
        },
        {
          id: 110,
          name: "kpi-tiles",
          description: "KPI tiles in a grid layout. For displaying key metrics and participation statistics.",
          position: 7,
          hidden: false,
          hidden_until: nil,
          file: "data/110_kpi_tiles.html"
        },
        {
          id: 111,
          name: "kpi-central",
          description: "Central KPI display with prominent numbers. For highlighting a single key metric or result.",
          position: 8,
          hidden: false,
          hidden_until: nil,
          file: "data/111_kpi_central.html"
        },
        {
          id: 112,
          name: "kpi-icons",
          description: "KPIs with accompanying icons. For metrics with visual category indicators.",
          position: 9,
          hidden: false,
          hidden_until: nil,
          file: "data/112_kpi_icons.html"
        },
        {
          id: 113,
          name: "kpi-progress",
          description: "KPIs with progress bars. For showing completion rates, goals, or target achievement.",
          position: 10,
          hidden: false,
          hidden_until: nil,
          file: "data/113_kpi_progress.html"
        },
        {
          id: 114,
          name: "compare-before-after",
          description: "Before/after comparison layout. For showing changes, renovations, or development progress.",
          position: 11,
          hidden: false,
          hidden_until: nil,
          file: "data/114_compare_before_after.html"
        },
        {
          id: 115,
          name: "compare-matrix",
          description: "Comparison matrix with rows and columns. For structured feature or option comparisons.",
          position: 12,
          hidden: false,
          hidden_until: nil,
          file: "data/115_compare_matrix.html"
        },
        {
          id: 116,
          name: "compare-proscons",
          description: "Pros and cons comparison. For balanced presentation of advantages and disadvantages.",
          position: 13,
          hidden: false,
          hidden_until: nil,
          file: "data/116_compare_proscons.html"
        },
        {
          id: 117,
          name: "dodont-sidebyside",
          description: "Do/Don't side-by-side layout. For guidelines, rules, and behavioral recommendations.",
          position: 14,
          hidden: false,
          hidden_until: nil,
          file: "data/117_dodont_sidebyside.html"
        },
        {
          id: 118,
          name: "dodont-traffic",
          description: "Do/Don't with traffic light colors. For clear visual guidance using green/red indicators.",
          position: 15,
          hidden: false,
          hidden_until: nil,
          file: "data/118_dodont_traffic.html"
        }
      ]
    },
    {
      id: 7,
      name_de: "Interaktionen",
      name_en: "Interactions",
      section: "general",
      position: 6,
      directory: "interactions",
      templates: [
        {
          id: 119,
          name: "cta-centered-dark",
          description: "Centered call-to-action with dark background. For prominent action prompts and participation links.",
          position: 1,
          hidden: false,
          hidden_until: nil,
          file: "interactions/119_cta_centered_dark.html"
        },
        {
          id: 120,
          name: "cta-split",
          description: "Split call-to-action with text and button side by side. For contextual action prompts.",
          position: 2,
          hidden: false,
          hidden_until: nil,
          file: "interactions/120_cta_split.html"
        },
        {
          id: 121,
          name: "cta-multi",
          description: "Multiple call-to-action buttons. For offering several participation options or next steps.",
          position: 3,
          hidden: false,
          hidden_until: nil,
          file: "interactions/121_cta_multi.html"
        },
        {
          id: 122,
          name: "cta-banner",
          description: "Call-to-action as a banner strip. For attention-grabbing action bars across the page.",
          position: 4,
          hidden: false,
          hidden_until: nil,
          file: "interactions/122_cta_banner.html"
        },
        {
          id: 123,
          name: "cta-stats",
          description: "Call-to-action combined with statistics. For motivating action with participation numbers.",
          position: 5,
          hidden: false,
          hidden_until: nil,
          file: "interactions/123_cta_stats.html"
        },
        {
          id: 124,
          name: "faq-standard",
          description: "Standard FAQ accordion. For frequently asked questions with expandable answers.",
          position: 6,
          hidden: false,
          hidden_until: nil,
          file: "interactions/124_faq_standard.html"
        },
        {
          id: 125,
          name: "faq-icons",
          description: "FAQ with category icons. For visually categorized questions and answers.",
          position: 7,
          hidden: false,
          hidden_until: nil,
          file: "interactions/125_faq_icons.html"
        },
        {
          id: 126,
          name: "faq-grouped",
          description: "FAQ organized in topic groups. For structured Q&A sections with multiple categories.",
          position: 8,
          hidden: false,
          hidden_until: nil,
          file: "interactions/126_faq_grouped.html"
        },
        {
          id: 127,
          name: "faq-cards",
          description: "FAQ displayed as individual cards. For visually distinct question-answer pairs.",
          position: 9,
          hidden: false,
          hidden_until: nil,
          file: "interactions/127_faq_cards.html"
        },
        {
          id: 128,
          name: "grusswort-light",
          description: "Welcome message on light background. For mayor greetings and official introductory statements.",
          position: 10,
          hidden: false,
          hidden_until: nil,
          file: "interactions/128_grusswort_light.html"
        },
        {
          id: 129,
          name: "grusswort-dark",
          description: "Welcome message on dark background. For mayor greetings with a formal, prominent appearance.",
          position: 11,
          hidden: false,
          hidden_until: nil,
          file: "interactions/129_grusswort_dark.html"
        }
      ]
    },
    {
      id: 8,
      name_de: "Newsletter",
      name_en: "Newsletter",
      section: "newsletter_email",
      position: 7,
      directory: "newsletter",
      templates: [
        {
          id: 131,
          name: "nl-masthead",
          description: "Newsletter header bar with title, issue line, and optional logo. For the top of every newsletter edition.",
          position: 1,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/131_nl_masthead.html"
        },
        {
          id: 132,
          name: "nl-text",
          description: "Heading with body paragraphs. For standard newsletter copy, intros, and announcements.",
          position: 2,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/132_nl_text.html"
        },
        {
          id: 133,
          name: "nl-button-cta",
          description: "Centered call-to-action with a bulletproof button. For survey, voting, or participation links.",
          position: 3,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/133_nl_button_cta.html"
        },
        {
          id: 134,
          name: "nl-image-text",
          description: "Image and text side by side, stacked on mobile. For project highlights with a photo.",
          position: 4,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/134_nl_image_text.html"
        },
        {
          id: 136,
          name: "nl-divider",
          description: "Thin divider line with vertical spacing. For visual separation between sections.",
          position: 5,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/136_nl_divider.html"
        },
        {
          id: 137,
          name: "nl-highlight",
          description: "Highlighted notice box with accent border. For important notes, deadlines, and key messages.",
          position: 6,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/137_nl_highlight.html"
        },
        {
          id: 138,
          name: "nl-list",
          description: "Checkmark list. For enumerations, checklists, benefits, or steps.",
          position: 7,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/138_nl_list.html"
        },
        {
          id: 139,
          name: "nl-article-teaser",
          description: "Linked article or project teasers with short blurbs. For 'from our projects', blog links, and further reading.",
          position: 8,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/139_nl_article_teaser.html"
        },
        {
          id: 140,
          name: "nl-stats",
          description: "Three key figures side by side, stacked on mobile. For participation numbers and results.",
          position: 9,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/140_nl_stats.html"
        },
        {
          id: 141,
          name: "nl-two-column",
          description: "Two text columns side by side, stacked on mobile. For parallel content or comparisons.",
          position: 10,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/141_nl_two_column.html"
        },
        {
          id: 142,
          name: "nl-quote",
          description: "Quote with accent border and attribution. For citizen voices, statements, and testimonials.",
          position: 11,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/142_nl_quote.html"
        },
        {
          id: 143,
          name: "nl-image-full",
          description: "Large full-width image with caption. For impressions, maps, and visualizations.",
          position: 12,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/143_nl_image_full.html"
        },
        {
          id: 144,
          name: "nl-event",
          description: "Event entry with date badge, details, and link. For events, workshops, and meeting dates.",
          position: 13,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/144_nl_event.html"
        },
        {
          id: 145,
          name: "nl-cta-banner",
          description: "Colored call-to-action banner with text and button. For a prominent, full-width action prompt.",
          position: 14,
          hidden: false,
          hidden_until: nil,
          file: "newsletter/145_nl_cta_banner.html"
        }
      ]
    },
    {
      id: 9,
      name_de: "Projekt Karten",
      name_en: "Project Maps",
      section: "general",
      position: 8,
      directory: "project_maps",
      templates: [
        {
          id: 146,
          name: "Karte vollflächig",
          description: "Vollflächige Kartenansicht mit Titelleiste. Die Karte wird auf der Projektseite zur echten interaktiven Karte (Leaflet/Mapbox/VC Map je nach Projekteinstellung).",
          position: 1,
          hidden: false,
          hidden_until: nil,
          file: "project_maps/146_karte_vollflaechig.html"
        },
        {
          id: 147,
          name: "Karte mit Kopfzeile",
          description: "Einleitende Kopfzeile (Label, Titel, Beschreibung) über einer vollflächigen Karte. Map-Bereich wird auf der Projektseite zur echten Karte.",
          position: 2,
          hidden: false,
          hidden_until: nil,
          file: "project_maps/147_karte_mit_kopfzeile.html"
        },
        {
          id: 148,
          name: "Karte & Text (Split)",
          description: "Zweispaltig: Karte links, Beschreibung, Kennzahlen und Button rechts. Spalten brechen auf schmalen Bildschirmen um.",
          position: 3,
          hidden: false,
          hidden_until: nil,
          file: "project_maps/148_karte_text_split.html"
        },
        {
          id: 149,
          name: "Karte mit Aktionsleiste",
          description: "Vollflächige Karte mit auffälliger Aktionsleiste (Aufruf + Button) darunter — für Beteiligungskarten.",
          position: 4,
          hidden: false,
          hidden_until: nil,
          file: "project_maps/149_karte_mit_aktionsleiste.html"
        },
        {
          id: 150,
          name: "Kennzahlen mit Mini-Karte",
          description: "Kennzahlen-Raster (2×2) links, kompakte Karte rechts. Gut als Überblicks- oder Steckbrief-Block.",
          position: 5,
          hidden: false,
          hidden_until: nil,
          file: "project_maps/150_kennzahlen_mit_mini_karte.html"
        },
        {
          id: 151,
          name: "Karte mit Ebenen-Filter",
          description: "Statische Ebenen-Chips über der Karte (dekorativ, nicht mit Kartenebenen verknüpft). Nur der Kartenbereich wird zur echten Karte.",
          position: 6,
          hidden: false,
          hidden_until: nil,
          file: "project_maps/151_karte_mit_ebenen_filter.html"
        }
      ]
    }
  ].freeze
end
