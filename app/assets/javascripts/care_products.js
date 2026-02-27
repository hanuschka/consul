// ============================================================
// Care Products – Cart, Wishlist, Search, Sort, Countdown
// ============================================================

// ---- Cart ----
var CareCart = (function() {
  "use strict";
  var STORAGE_KEY = "care_cart";

  function load() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || []; }
    catch (e) { return []; }
  }

  function save(items) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  }

  function add(product) {
    var items = load();
    var existing = items.find(function(i) { return i.id === product.id; });
    if (existing) {
      existing.qty = (existing.qty || 1) + (product.qty || 1);
    } else {
      items.push({ id: product.id, name: product.name, price: product.price,
                   emoji: product.emoji, qty: product.qty || 1 });
    }
    save(items);
    updateBadge();
    showToast("🛒 \"" + product.name + "\" zum Warenkorb hinzugefügt");
  }

  function remove(productId) {
    save(load().filter(function(i) { return i.id !== productId; }));
    updateBadge();
    renderCartPanel();
  }

  function totalCount() {
    return load().reduce(function(sum, i) { return sum + (i.qty || 1); }, 0);
  }

  function updateBadge() {
    var badge = document.getElementById("care-cart-badge");
    if (!badge) return;
    var count = totalCount();
    badge.textContent = count;
    badge.style.display = count > 0 ? "flex" : "none";
  }

  function showToast(msg) {
    var toast = document.getElementById("care-toast");
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add("visible");
    clearTimeout(toast._timer);
    toast._timer = setTimeout(function() { toast.classList.remove("visible"); }, 3000);
  }

  function renderCartPanel() {
    var panel = document.getElementById("care-cart-panel-items");
    if (!panel) return;
    var items = load();

    if (items.length === 0) {
      panel.innerHTML = '<p class="care-cart-empty">Ihr Warenkorb ist leer.</p>';
      var tot = document.getElementById("care-cart-total");
      if (tot) tot.textContent = "0,00 €";
      return;
    }

    var html = "";
    var total = 0;
    items.forEach(function(item) {
      var priceNum = parseFloat(item.price.replace(",", ".").replace(/[^0-9.]/g, "")) || 0;
      total += priceNum * (item.qty || 1);
      html += '<div class="care-cart-item">';
      html += '<span class="care-cart-item-emoji">' + (item.emoji || "🧴") + '</span>';
      html += '<div class="care-cart-item-info">';
      html += '<span class="care-cart-item-name">' + item.name + '</span>';
      html += '<span class="care-cart-item-price">' + item.qty + ' × ' + item.price + '</span>';
      html += '</div>';
      html += '<button class="care-cart-remove" data-id="' + item.id + '">✕</button>';
      html += '</div>';
    });
    panel.innerHTML = html;

    var totEl = document.getElementById("care-cart-total");
    if (totEl) totEl.textContent = total.toFixed(2).replace(".", ",") + " €";

    panel.querySelectorAll(".care-cart-remove").forEach(function(btn) {
      btn.addEventListener("click", function() { remove(btn.dataset.id); });
    });
  }

  function togglePanel() {
    var panel = document.getElementById("care-cart-panel");
    if (!panel) return;
    panel.classList.toggle("open");
    if (panel.classList.contains("open")) renderCartPanel();
  }

  function initButtons() {
    document.querySelectorAll("[data-care-add-cart]").forEach(function(btn) {
      if (btn._careCartBound) return;
      btn._careCartBound = true;
      btn.addEventListener("click", function() {
        add({ id: btn.dataset.productId, name: btn.dataset.productName,
              price: btn.dataset.productPrice, emoji: btn.dataset.productEmoji, qty: 1 });
        var orig = btn.textContent;
        btn.textContent = "✓ Hinzugefügt!";
        btn.style.background = "#357a62";
        setTimeout(function() { btn.textContent = orig; btn.style.background = ""; }, 2000);
      });
    });
  }

  function init() {
    updateBadge();
    var trigger = document.getElementById("care-cart-trigger");
    if (trigger) trigger.addEventListener("click", function(e) { e.preventDefault(); togglePanel(); });
    var closeBtn = document.getElementById("care-cart-close");
    if (closeBtn) closeBtn.addEventListener("click", function() {
      document.getElementById("care-cart-panel").classList.remove("open");
    });
    initButtons();
  }

  return { add: add, remove: remove, load: load, init: init, initButtons: initButtons };
})();

// ---- Wishlist ----
var CareWishlist = (function() {
  "use strict";
  var STORAGE_KEY = "care_wishlist";

  function load() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || []; }
    catch (e) { return []; }
  }

  function save(items) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  }

  function toggle(product) {
    var items = load();
    var idx = items.findIndex(function(i) { return i.id === product.id; });
    if (idx > -1) {
      items.splice(idx, 1);
      CareCart.init && CareCart.init();   // refresh toast system
      showToast("💔 \"" + product.name + "\" von der Wunschliste entfernt");
    } else {
      items.push(product);
      showToast("❤️ \"" + product.name + "\" zur Wunschliste hinzugefügt");
    }
    save(items);
    renderPanel();
    return idx === -1;   // true = now on list
  }

  function isOn(productId) {
    return load().some(function(i) { return String(i.id) === String(productId); });
  }

  function showToast(msg) {
    var toast = document.getElementById("care-toast");
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add("visible");
    clearTimeout(toast._timer);
    toast._timer = setTimeout(function() { toast.classList.remove("visible"); }, 3000);
  }

  function renderPanel() {
    var panel = document.getElementById("care-wishlist-items");
    if (!panel) return;
    var items = load();
    if (items.length === 0) {
      panel.innerHTML = '<p class="care-cart-empty">Ihre Wunschliste ist leer.</p>';
      return;
    }
    var html = "";
    items.forEach(function(item) {
      html += '<div class="care-wishlist-item">';
      html += '<span class="care-cart-item-emoji">' + (item.emoji || "🧴") + '</span>';
      html += '<span class="care-cart-item-name">' + item.name + '</span>';
      html += '<button class="care-wishlist-remove" data-id="' + item.id + '">✕</button>';
      html += '</div>';
    });
    panel.innerHTML = html;
    panel.querySelectorAll(".care-wishlist-remove").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var its = load().filter(function(i) { return String(i.id) !== btn.dataset.id; });
        save(its);
        renderPanel();
        refreshHearts();
      });
    });
  }

  function refreshHearts() {
    document.querySelectorAll(".care-wishlist-btn").forEach(function(btn) {
      var pid = btn.dataset.productId;
      btn.textContent = isOn(pid) ? "❤️" : "♡";
      btn.classList.toggle("active", isOn(pid));
    });
  }

  function init() {
    refreshHearts();

    document.querySelectorAll(".care-wishlist-btn").forEach(function(btn) {
      if (btn._wishlistBound) return;
      btn._wishlistBound = true;
      btn.addEventListener("click", function(e) {
        e.preventDefault();
        var icon = btn.dataset.productEmoji || "🧴";
        var added = toggle({ id: btn.dataset.productId, name: btn.dataset.productName, emoji: icon });
        btn.textContent = added ? "❤️" : "♡";
        btn.classList.toggle("active", added);
      });
    });

    // Wunschliste-Panel öffnen/schließen
    var wishBtn = document.getElementById("care-wishlist-trigger");
    if (wishBtn) wishBtn.addEventListener("click", function() {
      document.getElementById("care-wishlist-panel").classList.toggle("open");
      renderPanel();
    });

    var closeBtn = document.getElementById("care-wishlist-close");
    if (closeBtn) closeBtn.addEventListener("click", function() {
      document.getElementById("care-wishlist-panel").classList.remove("open");
    });
  }

  return { init: init, isOn: isOn };
})();

// ---- Live Search & Sort ----
var CareSearch = (function() {
  "use strict";

  function getCards() {
    return Array.from(document.querySelectorAll(".care-product-col"));
  }

  function filter() {
    var query = (document.getElementById("care-search-input") || {}).value || "";
    query = query.toLowerCase().trim();
    var sort = (document.getElementById("care-sort-select") || {}).value || "default";
    var cards = getCards();
    var clearBtn = document.getElementById("care-search-clear");

    if (clearBtn) clearBtn.style.display = query ? "inline-block" : "none";

    // Filter visibility
    var visible = [];
    cards.forEach(function(card) {
      var name = (card.dataset.name || "").toLowerCase();
      var matches = !query || name.indexOf(query) > -1;
      card.style.display = matches ? "" : "none";
      if (matches) visible.push(card);
    });

    // Sort
    if (sort !== "default" && visible.length > 1) {
      var grid = document.getElementById("care-products-grid");
      if (grid) {
        visible.sort(function(a, b) {
          if (sort === "price-asc")  return parseInt(a.dataset.price) - parseInt(b.dataset.price);
          if (sort === "price-desc") return parseInt(b.dataset.price) - parseInt(a.dataset.price);
          if (sort === "rating-desc") return parseFloat(b.dataset.rating) - parseFloat(a.dataset.rating);
          if (sort === "reviews-desc") return parseInt(b.dataset.reviews) - parseInt(a.dataset.reviews);
          if (sort === "name-asc") return (a.dataset.name || "").localeCompare(b.dataset.name || "");
          return 0;
        });
        visible.forEach(function(card) { grid.appendChild(card); });
      }
    }

    // Count + no-results
    var countEl = document.getElementById("care-results-count");
    if (countEl) countEl.textContent = visible.length + " Produkte";
    var noResults = document.getElementById("care-no-results");
    if (noResults) noResults.style.display = visible.length === 0 ? "block" : "none";
  }

  function init() {
    var input = document.getElementById("care-search-input");
    var select = document.getElementById("care-sort-select");
    var clearBtn = document.getElementById("care-search-clear");
    var resetBtn = document.getElementById("care-btn-reset-search");

    if (input) input.addEventListener("input", filter);
    if (select) select.addEventListener("change", filter);
    if (clearBtn) clearBtn.addEventListener("click", function() {
      input.value = "";
      filter();
      input.focus();
    });
    if (resetBtn) resetBtn.addEventListener("click", function() {
      if (input) input.value = "";
      if (select) select.value = "default";
      filter();
    });
  }

  return { init: init };
})();

// ---- Countdown ----
var CareSaleCountdown = (function() {
  "use strict";

  function init() {
    var el = document.getElementById("care-countdown-timer");
    if (!el) return;

    // Enddatum: nächsten Sonntag 23:59:59
    var now = new Date();
    var end = new Date(now);
    end.setDate(now.getDate() + (7 - now.getDay()) % 7 || 7);
    end.setHours(23, 59, 59, 0);

    var interval = setInterval(function() {
      var diff = end - new Date();
      if (diff <= 0) { el.textContent = "Abgelaufen"; clearInterval(interval); return; }
      var h = Math.floor(diff / 3600000);
      var m = Math.floor((diff % 3600000) / 60000);
      var s = Math.floor((diff % 60000) / 1000);
      el.textContent =
        String(h).padStart(2, "0") + ":" +
        String(m).padStart(2, "0") + ":" +
        String(s).padStart(2, "0");
    }, 1000);
  }

  return { init: init };
})();

// ---- Scroll-to-Top ----
var CareScrollTop = (function() {
  "use strict";

  function init() {
    var btn = document.getElementById("care-scroll-top");
    if (!btn) return;

    window.addEventListener("scroll", function() {
      btn.classList.toggle("visible", window.scrollY > 400);
    });

    btn.addEventListener("click", function() {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  }

  return { init: init };
})();

// ---- Bootstrap ----
$(document).on("turbolinks:load", function() {
  CareCart.init();
  CareWishlist.init();
  CareSearch.init();
  CareSaleCountdown.init();
  CareScrollTop.init();
});
