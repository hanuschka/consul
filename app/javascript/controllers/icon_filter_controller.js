import { Controller } from "@hotwired/stimulus"

const GERMAN_KEYWORDS = {
  "auto": ["car", "taxi", "truck", "bus", "shuttle-van"],
  "baum": ["tree", "leaf", "seedling"],
  "haus": ["home", "house-damage", "house-user"],
  "herz": ["heart", "heart-broken", "heartbeat"],
  "stern": ["star", "star-half", "star-half-alt"],
  "mensch": ["user", "users", "walking", "running", "child", "person-booth", "people-carry"],
  "nutzer": ["user", "users", "user-friends", "user-circle", "user-plus"],
  "telefon": ["phone", "phone-alt", "phone-square", "mobile"],
  "brief": ["envelope", "mail-bulk", "paper-plane"],
  "karte": ["map", "map-marked", "map-marked-alt", "map-marker", "map-marker-alt", "map-pin", "map-signs"],
  "wasser": ["water", "tint", "faucet", "swimming-pool"],
  "feuer": ["fire", "fire-alt", "fire-extinguisher"],
  "buch": ["book", "journal-whills"],
  "musik": ["music", "guitar", "headphones"],
  "geld": ["money-bill", "money-bill-alt", "money-check", "coins", "euro-sign", "piggy-bank", "wallet"],
  "schule": ["school", "graduation-cap", "university"],
  "krankenhaus": ["hospital", "hospital-alt", "ambulance", "first-aid", "medkit"],
  "gesundheit": ["heartbeat", "stethoscope", "pills", "syringe", "thermometer"],
  "sport": ["football-ball", "baseball-ball", "basketball-ball", "volleyball-ball", "swimming-pool", "running", "biking", "skiing"],
  "essen": ["utensils", "pizza-slice", "hamburger", "hotdog", "ice-cream", "apple-alt", "lemon", "bacon"],
  "wetter": ["cloud-rain", "sun", "snowflake", "wind", "umbrella"],
  "verkehr": ["traffic-light", "road", "car", "bus", "train", "tram", "bicycle", "truck"],
  "umwelt": ["leaf", "tree", "seedling", "recycle", "solar-panel", "globe"],
  "sicherheit": ["shield-alt", "lock", "key", "fingerprint"],
  "tier": ["dog", "paw", "crow", "horse", "frog", "fish", "spider", "cat"],
  "hund": ["dog", "paw"],
  "katze": ["cat"],
  "vogel": ["crow", "feather"],
  "pflanze": ["leaf", "seedling", "tree"],
  "blume": ["seedling", "spa"],
  "sonne": ["sun", "solar-panel"],
  "mond": ["moon"],
  "berg": ["mountain"],
  "flugzeug": ["plane", "plane-arrival", "plane-departure"],
  "zug": ["train", "tram", "subway"],
  "fahrrad": ["bicycle", "biking"],
  "schiff": ["ship", "anchor"],
  "rakete": ["rocket"],
  "werkzeug": ["tools", "wrench", "screwdriver", "hammer", "toolbox"],
  "strom": ["bolt", "plug", "battery-full", "battery-half"],
  "licht": ["lightbulb", "sun"],
  "kamera": ["camera", "video", "film"],
  "uhr": ["clock", "hourglass", "stopwatch"],
  "kalender": ["calendar", "calendar-alt"],
  "wolke": ["cloud", "cloud-rain"],
  "gift": ["gift", "gifts"],
  "geschenk": ["gift", "gifts"],
  "muell": ["trash-alt", "recycle"],
  "kind": ["child", "baby", "baby-carriage"],
  "familie": ["users", "user-friends", "people-carry"],
  "kirche": ["church", "place-of-worship"],
  "flagge": ["flag", "flag-checkered"],
  "globus": ["globe", "globe-europe", "globe-americas", "globe-africa", "globe-asia"],
  "welt": ["globe", "globe-europe", "globe-americas"],
  "stadt": ["city", "building", "store"],
  "gebaeude": ["building", "store", "warehouse", "hospital"],
  "park": ["tree", "leaf", "bench"],
  "straße": ["road", "street-view", "map-signs"],
  "strasse": ["road", "street-view", "map-signs"],
  "bruecke": ["bridge"],
  "abstimmung": ["vote-yea", "poll", "poll-h", "check", "check-circle"],
  "wahl": ["vote-yea", "poll", "check-circle"],
  "hand": ["hand-paper", "hand-point-up", "hand-peace", "handshake", "thumbs-up", "thumbs-down", "fist-raised"],
  "daumen": ["thumbs-up", "thumbs-down"],
  "info": ["info", "info-circle", "question", "question-circle"],
  "warnung": ["exclamation-triangle", "exclamation", "exclamation-circle"],
  "suche": ["search", "search-plus", "search-minus"],
  "einstellung": ["cog", "cogs", "sliders-h"],
  "pfeil": ["arrow-up", "arrow-down", "arrow-left", "arrow-right"],
  "plus": ["plus", "plus-circle", "plus-square"],
  "minus": ["minus", "minus-circle", "minus-square"],
  "kreuz": ["times", "times-circle"],
  "haken": ["check", "check-circle", "check-square"],
}

export default class extends Controller {
  static targets = ["search", "list"]

  preventSubmit(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this._applyFilter()
    }
  }

  filter() {
    this._applyFilter()
  }

  _applyFilter() {
    const query = this.searchTarget.value.toLowerCase().trim()
    const items = this.listTarget.querySelectorAll("[data-icon-name]")

    if (!query) {
      items.forEach(item => item.style.display = "")
      return
    }

    const germanMatches = new Set()
    for (const [keyword, icons] of Object.entries(GERMAN_KEYWORDS)) {
      if (keyword.includes(query)) {
        icons.forEach(icon => germanMatches.add(icon))
      }
    }

    items.forEach(item => {
      const name = item.dataset.iconName.toLowerCase()
      const match = name.includes(query) || germanMatches.has(name)
      item.style.display = match ? "" : "none"
    })
  }
}
