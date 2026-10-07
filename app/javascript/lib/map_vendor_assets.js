/**
 * Loaders for the self-hosted Leaflet and Mapbox GL vendor packs.
 *
 * Both libraries are UMD builds served from our own host by Sprockets, so
 * they are pulled in with plain <script>/<link> tags on first use rather than
 * bundled into the pack: a page without a map must not download them, and
 * sending the visitor's IP to a public CDN before consent is not permitted.
 *
 * window.VendorAssetUrls carries the fingerprinted URLs and is defined by
 * app/assets/javascripts/vendor_asset_urls.js.erb, which the layout includes
 * ahead of this pack.
 */

const loadedScripts = {}

const loadScript = (src) => {
  if (loadedScripts[src]) return loadedScripts[src]

  loadedScripts[src] = new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = src
    script.async = false
    script.addEventListener("load", () => resolve())
    script.addEventListener("error", () => reject(new Error(`Failed to load ${src}`)))
    document.head.appendChild(script)
  })

  return loadedScripts[src]
}

const loadStylesheet = (href) => {
  if (document.querySelector(`link[href="${href}"]`)) return

  const link = document.createElement("link")
  link.rel = "stylesheet"
  link.href = href
  document.head.appendChild(link)
}

const vendorUrls = () => window.VendorAssetUrls || {}

export const loadLeaflet = () => {
  if (window.L) return Promise.resolve()

  loadStylesheet(vendorUrls().leafletCss)

  return loadScript(vendorUrls().leafletJs)
}

export const loadMapbox = () => {
  if (window.mapboxgl) return Promise.resolve()

  loadStylesheet(vendorUrls().mapboxCss)

  return loadScript(vendorUrls().mapboxJs)
}
