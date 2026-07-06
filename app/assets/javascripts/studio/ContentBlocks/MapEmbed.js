// Hydrates map-embed placeholders into real maps in studio/editor contexts.
//
// A map content-block template marks its map region with
// `<div class="projekt-map-embed js-projekt-map-embed ...">{{projekt_map}}</div>`.
// On a published page the server expands {{projekt_map}} via process_shortcodes,
// so the map is already real and this module is a no-op there. In the studio a
// freshly inserted block still holds the raw token, so we fetch the
// server-rendered map markup (identical to the published output) and inject it
// for display. On a projekt page that markup is the projekt's own map; off a
// projekt page (e.g. the homepage) it is the city map with all projekts.
//
// Invariant: the SAVED content-block body must always keep the placeholder
// token, never a hydrated map. Crud.updateContentBlock normalizes the saved
// HTML via App.Studio.utils.resetMapEmbeds and then re-hydrates the live
// DOM for display, so the DB stays canonical while the editor shows a map.
App.Studio.ContentBlocks.MapEmbed = {
  TOKEN: "{{projekt_map}}",
  selector: ".js-projekt-map-embed",
  fetchCache: {},
  instanceCounter: 0,

  initialize() {
    this.hydrateIn(document);
  },

  hydrateIn(container) {
    if (!container || !container.querySelectorAll) return;

    container.querySelectorAll(this.selector).forEach((embed) => {
      this.hydrateEmbed(embed);
    });
  },

  hydrateEmbed(embed) {
    if (!this.needsHydration(embed)) return;

    this.fetchMapHtml(this.mapEmbedUrl(embed))
      .then((html) => {
        if (!html || !this.needsHydration(embed)) return;

        this.injectMap(embed, html);
      })
      .catch(() => {});
  },

  // Strips the hydrated map, restores the placeholder token and re-hydrates —
  // used by the map source control to preview a resource/phase change.
  rehydrate(embed) {
    embed.querySelectorAll(".projekt-map-shortcode").forEach((map) => map.remove());

    if (embed.innerHTML.indexOf(this.TOKEN) === -1) {
      embed.appendChild(document.createTextNode(this.TOKEN));
    }

    this.hydrateEmbed(embed);
  },

  needsHydration(embed) {
    return embed.innerHTML.indexOf(this.TOKEN) !== -1;
  },

  // On a projekt page the embed renders that projekt's map; off a projekt page
  // (e.g. the homepage) it renders the city map with all projekts. The embed's
  // persisted resource/phase choice travels along so the preview matches the
  // published output.
  mapEmbedUrl(embed) {
    const projektId = this.currentProjektId();
    const baseUrl = projektId ? `/projekts/${projektId}/map_embed` : "/projekts_map_embed";
    const params = new URLSearchParams();

    if (embed.dataset.mapResource) params.set("resource", embed.dataset.mapResource);
    if (embed.dataset.mapPhaseId) params.set("phase_id", embed.dataset.mapPhaseId);

    const query = params.toString();

    return query ? `${baseUrl}?${query}` : baseUrl;
  },

  currentProjektId() {
    if (typeof App.Studio.Projekt === "undefined") return null
    if (!App.Studio.Projekt.isProjektPage()) return null

    return App.Studio.Projekt.getCurrentProjektId();
  },

  // Per-URL promise cache: every embed sharing a URL renders the same map, so
  // one request serves them all and re-hydration after save is instant.
  fetchMapHtml(url) {
    if (this.fetchCache[url]) return this.fetchCache[url];

    const request = fetch(url, {
      credentials: "same-origin",
      headers: { "X-Requested-With": "XMLHttpRequest" }
    }).then((response) => {
      if (!response.ok) throw new Error(`map_embed responded ${response.status}`);

      return response.text();
    });

    this.fetchCache[url] = request;
    request.catch(() => { delete this.fetchCache[url]; });

    return request;
  },

  injectMap(embed, html) {
    const walker = document.createTreeWalker(embed, NodeFilter.SHOW_TEXT, null, false);
    let node;

    while ((node = walker.nextNode())) {
      if (node.nodeValue.indexOf(this.TOKEN) === -1) continue;

      const mapElement = App.Studio.utils.htmlToDomElement(html).firstElementChild;
      if (!mapElement) return;

      this.uniquifyMapId(mapElement);
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
  },

  // The cached /map_embed response carries one server-generated DOM id; reusing
  // it for every embed of the same projekt would collide on getElementById and
  // leave all but the first map uninitialized. Give each injected map a fresh
  // unique id before App.Map binds to it.
  uniquifyMapId(mapElement) {
    const mapNode = mapElement.matches("[data-map]")
      ? mapElement
      : mapElement.querySelector("[data-map]");
    if (!mapNode) return;

    this.instanceCounter += 1;
    mapNode.id = `${mapNode.id || "map"}_e${this.instanceCounter}`;
  }
};
