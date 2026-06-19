// Hydrates map-embed placeholders into real maps in studio/editor contexts.
//
// A map content-block template marks its map region with
// `<div class="projekt-map-embed js-projekt-map-embed ...">{{projekt_map}}</div>`.
// On a published projekt page the server expands {{projekt_map}} via
// process_shortcodes, so the map is already real and this module is a no-op
// there. In the studio a freshly inserted block still holds the raw token, so
// we fetch the server-rendered map markup (identical to the published output)
// and inject it for display.
//
// Invariant: the SAVED content-block body must always keep the placeholder
// token, never a hydrated map. Crud.updateContentBlock normalizes the saved
// HTML via ProjektStudio.utils.resetMapEmbeds and then re-hydrates the live
// DOM for display, so the DB stays canonical while the editor shows a map.
App.ContentBlockEditor.MapEmbed = {
  TOKEN: "{{projekt_map}}",
  selector: ".js-projekt-map-embed",
  fetchCache: {},

  initialize() {
    this.hydrateIn(document);
  },

  hydrateIn(container) {
    if (!container || !container.querySelectorAll) return;

    const projektId = this.currentProjektId();
    if (!projektId) return;

    container.querySelectorAll(this.selector).forEach((embed) => {
      if (!this.needsHydration(embed)) return;

      this.fetchMapHtml(projektId)
        .then((html) => {
          if (!html || !this.needsHydration(embed)) return;

          this.injectMap(embed, html);
        })
        .catch(() => {});
    });
  },

  needsHydration(embed) {
    return embed.innerHTML.indexOf(this.TOKEN) !== -1;
  },

  currentProjektId() {
    if (typeof ProjektStudio === "undefined") return null
    if (!ProjektStudio.isProjektPage()) return null

    return ProjektStudio.getCurrentProjektId();
  },

  // Per-projekt promise cache: every embed of the same projekt renders the
  // same map, so one request serves them all and re-hydration after save is
  // instant.
  fetchMapHtml(projektId) {
    if (this.fetchCache[projektId]) return this.fetchCache[projektId];

    const url = `/projekts/${projektId}/map_embed`;

    const request = fetch(url, {
      credentials: "same-origin",
      headers: { "X-Requested-With": "XMLHttpRequest" }
    }).then((response) => {
      if (!response.ok) throw new Error(`map_embed responded ${response.status}`);

      return response.text();
    });

    this.fetchCache[projektId] = request;
    request.catch(() => { delete this.fetchCache[projektId]; });

    return request;
  },

  injectMap(embed, html) {
    const walker = document.createTreeWalker(embed, NodeFilter.SHOW_TEXT, null, false);
    let node;

    while ((node = walker.nextNode())) {
      if (node.nodeValue.indexOf(this.TOKEN) === -1) continue;

      const mapElement = ProjektStudio.utils.htmlToDomElement(html).firstElementChild;
      if (!mapElement) return;

      this.markNonEditable(mapElement);
      node.parentNode.replaceChild(mapElement, node);
      break;
    }

    if (App.Map && App.Map.refreshMapsIn) {
      App.Map.refreshMapsIn(embed);
    }
  },

  // The map is injected asynchronously, after SimpleEditMode's one-shot
  // non-editable scan has already run, and Leaflet keeps adding tiles/controls
  // afterwards. Marking the injected root contenteditable=false makes the whole
  // map subtree non-editable by inheritance regardless of that timing; the
  // class also keeps it excluded on later edit-mode scans.
  markNonEditable(mapElement) {
    mapElement.classList.add("js-content-block-element-not-editable");
    mapElement.contentEditable = false;
  }
};
