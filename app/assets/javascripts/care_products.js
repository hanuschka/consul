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

// ---- Promo Bar ----
var CarePromoBar = (function() {
  "use strict";
  var MSGS_KEY = "care_promo_closed";
  var current = 0;
  var interval;

  function init() {
    var bar = document.getElementById("care-promo-bar");
    if (!bar) return;

    // Already closed this session?
    if (sessionStorage.getItem(MSGS_KEY)) { bar.style.display = "none"; return; }

    var msgs = bar.querySelectorAll(".care-promo-msg");
    if (msgs.length > 1) {
      interval = setInterval(function() {
        msgs[current].classList.remove("active");
        current = (current + 1) % msgs.length;
        msgs[current].classList.add("active");
      }, 4000);
    }

    var closeBtn = document.getElementById("care-promo-close");
    if (closeBtn) closeBtn.addEventListener("click", function() {
      bar.classList.add("closing");
      clearInterval(interval);
      setTimeout(function() { bar.style.display = "none"; }, 300);
      sessionStorage.setItem(MSGS_KEY, "1");
    });
  }

  return { init: init };
})();

// ---- Coupon Codes ----
var CareCoupon = (function() {
  "use strict";
  var CODES = {
    "WILLKOMMEN10": { type: "percent", value: 10, label: "10 % Rabatt" },
    "SOMMER15":     { type: "percent", value: 15, label: "15 % Rabatt" },
    "PFLEGE5":      { type: "fixed",   value: 5,  label: "5,00 € Rabatt" }
  };

  var active = null;

  function apply(code) {
    var found = CODES[code.toUpperCase()];
    active = found || null;
    return active;
  }

  function discount(subtotal) {
    if (!active) return 0;
    if (active.type === "percent") return subtotal * active.value / 100;
    return Math.min(active.value, subtotal);
  }

  function init() {
    var btn = document.getElementById("care-coupon-btn");
    var input = document.getElementById("care-coupon-input");
    var msg = document.getElementById("care-coupon-msg");
    if (!btn || !input) return;

    btn.addEventListener("click", function() {
      var result = apply(input.value.trim());
      if (result) {
        msg.textContent = "✓ Gutschein eingelöst: " + result.label;
        msg.className = "care-coupon-msg care-coupon-success";
        input.disabled = true;
        btn.textContent = "Eingelöst";
        btn.disabled = true;
      } else {
        msg.textContent = "✗ Ungültiger Gutscheincode";
        msg.className = "care-coupon-msg care-coupon-error";
      }
      CareCart.refreshTotals && CareCart.refreshTotals();
    });
  }

  return { init: init, discount: discount, active: function() { return active; } };
})();

// ---- Star Picker (Review Form) ----
var CareReviewForm = (function() {
  "use strict";

  function init() {
    var picker = document.getElementById("care-star-picker");
    var ratingInput = document.getElementById("care-review-rating");
    var submitBtn = document.getElementById("care-btn-submit-review");
    var successEl = document.getElementById("care-review-success");

    if (!picker) return;

    var stars = picker.querySelectorAll(".care-star-pick");
    var selected = 0;

    function highlight(n) {
      stars.forEach(function(s, i) {
        s.classList.toggle("filled", i < n);
      });
    }

    stars.forEach(function(star, idx) {
      star.addEventListener("mouseover", function() { highlight(idx + 1); });
      star.addEventListener("mouseleave", function() { highlight(selected); });
      star.addEventListener("click", function() {
        selected = idx + 1;
        ratingInput.value = selected;
        highlight(selected);
      });
    });

    if (submitBtn) {
      submitBtn.addEventListener("click", function() {
        var name = (document.getElementById("care-review-name") || {}).value || "";
        var text = (document.getElementById("care-review-text") || {}).value || "";

        if (!selected) {
          alert("Bitte wählen Sie eine Sternebewertung.");
          return;
        }
        if (!name.trim()) {
          alert("Bitte geben Sie Ihren Namen ein.");
          return;
        }
        if (text.trim().length < 20) {
          alert("Bitte schreiben Sie mindestens 20 Zeichen.");
          return;
        }

        // Simulate submit
        submitBtn.textContent = "Wird gesendet …";
        submitBtn.disabled = true;
        setTimeout(function() {
          document.getElementById("care-review-form").style.display = "none";
          if (successEl) successEl.style.display = "block";
        }, 900);
      });
    }
  }

  return { init: init };
})();

// Extend CareCart to support coupon totals
(function() {
  var orig = CareCart.init;
  CareCart.refreshTotals = function() {
    var items = CareCart.load();
    var subtotal = items.reduce(function(s, i) {
      return s + (parseFloat(i.price.replace(",", ".").replace(/[^0-9.]/g, "")) || 0) * (i.qty || 1);
    }, 0);
    var discountAmt = CareCoupon.discount(subtotal);
    var total = Math.max(0, subtotal - discountAmt);

    var subEl = document.getElementById("care-cart-subtotal");
    var totEl = document.getElementById("care-cart-total");
    var discRow = document.getElementById("care-cart-discount-row");
    var discVal = document.getElementById("care-cart-discount-val");

    if (subEl) subEl.textContent = subtotal.toFixed(2).replace(".", ",") + " €";
    if (totEl) totEl.textContent = total.toFixed(2).replace(".", ",") + " €";
    if (discRow) discRow.style.display = discountAmt > 0 ? "flex" : "none";
    if (discVal) discVal.textContent = "−" + discountAmt.toFixed(2).replace(".", ",") + " €";
  };
})();

// ---- Hauttyp-Quiz ----
var CareQuiz = (function() {
  "use strict";

  var answers = {};
  var currentStep = 0;
  var totalQuestions = 4;

  var RESULTS = {
    "trocken-reich":    { type: "Trockene Haut",    desc: "Ihre Haut braucht intensive Pflege und viel Feuchtigkeit. Wir empfehlen reichhaltige Cremes mit Hyaluron und Sheabutter.", products: [1, 7] },
    "fettig-leicht":   { type: "Fettige Haut",     desc: "Ihre Haut produziert viel Talg. Leichte, nicht-komedogene Produkte sind ideal.", products: [3, 4] },
    "gemischt-mittel": { type: "Mischhaut",         desc: "T-Zone und Wangen brauchen unterschiedliche Pflege. Ausgewogene Produkte für jeden Bereich.", products: [1, 3] },
    "normal-mittel":   { type: "Normale Haut",      desc: "Sie haben die ideale Basis! Erhalten Sie das Gleichgewicht mit leichter täglicher Pflege.", products: [5, 2] },
    "empfindlich":     { type: "Empfindliche Haut", desc: "Ihre Haut reagiert sensibel. Parfümfreie Produkte mit beruhigenden Inhaltsstoffen sind perfekt.", products: [6, 1] }
  };

  var ALL_PRODUCTS = [
    { id: 1, name: "Feuchtigkeitscreme Premium", price: "24,99 €", emoji: "💧", url: "/pflegeartikel/1" },
    { id: 2, name: "Nährendes Haarshampoo",      price: "12,49 €", emoji: "✨", url: "/pflegeartikel/2" },
    { id: 3, name: "Verwöhn-Duschgel",           price: "8,99 €",  emoji: "🧴", url: "/pflegeartikel/3" },
    { id: 4, name: "Whitening Zahnpasta",         price: "6,99 €",  emoji: "🦷", url: "/pflegeartikel/4" },
    { id: 5, name: "Sonnenschutz LSF 50",         price: "18,99 €", emoji: "☀️", url: "/pflegeartikel/5" },
    { id: 6, name: "Baby Pflegelotion",           price: "9,99 €",  emoji: "🌸", url: "/pflegeartikel/6" },
    { id: 7, name: "Anti-Aging Serum",            price: "39,99 €", emoji: "💧", url: "/pflegeartikel/7" }
  ];

  function getResult() {
    var sensitivity = answers[2] || "nein";
    if (sensitivity === "ja") return RESULTS["empfindlich"];
    var skinType = answers[1] || "normal";
    var texture = answers[4] || "mittel";
    var key = skinType + "-" + texture;
    return RESULTS[key] || RESULTS["normal-mittel"];
  }

  function showStep(n) {
    document.querySelectorAll(".care-quiz-step").forEach(function(s) {
      s.classList.remove("active");
    });
    var step = document.querySelector("[data-step='" + n + "']");
    if (step) step.classList.add("active");

    var pct = n === 0 ? 0 : Math.round((n / (totalQuestions + 1)) * 100);
    var bar = document.getElementById("care-quiz-progress-bar");
    if (bar) bar.style.width = pct + "%";
    currentStep = n;
  }

  function showResult() {
    var result = getResult();
    var titleEl = document.getElementById("care-quiz-result-title");
    var descEl  = document.getElementById("care-quiz-result-desc");
    var recEl   = document.getElementById("care-quiz-recommendations");

    if (titleEl) titleEl.textContent = "Ihr Hauttyp: " + result.type;
    if (descEl)  descEl.textContent  = result.desc;

    if (recEl) {
      var html = "<h4>Empfohlene Produkte für Sie:</h4><div class='care-quiz-rec-grid'>";
      result.products.forEach(function(pid) {
        var p = ALL_PRODUCTS.find(function(x) { return x.id === pid; });
        if (!p) return;
        html += "<div class='care-quiz-rec-card'>";
        html += "<span class='care-quiz-rec-emoji'>" + p.emoji + "</span>";
        html += "<div class='care-quiz-rec-info'>";
        html += "<strong>" + p.name + "</strong>";
        html += "<span>" + p.price + "</span>";
        html += "</div>";
        html += "<a href='" + p.url + "' class='care-quiz-rec-btn'>Details</a>";
        html += "</div>";
      });
      html += "</div>";
      recEl.innerHTML = html;
    }

    showStep(5);
  }

  function open() {
    document.getElementById("care-quiz-modal").classList.add("open");
    document.getElementById("care-quiz-backdrop").classList.add("open");
    document.body.style.overflow = "hidden";
  }

  function close() {
    document.getElementById("care-quiz-modal").classList.remove("open");
    document.getElementById("care-quiz-backdrop").classList.remove("open");
    document.body.style.overflow = "";
  }

  function reset() {
    answers = {};
    currentStep = 0;
    document.querySelectorAll(".care-quiz-option").forEach(function(o) {
      o.classList.remove("selected");
    });
    showStep(0);
  }

  function init() {
    var trigger = document.getElementById("care-quiz-trigger");
    if (trigger) trigger.addEventListener("click", open);

    var closeBtn = document.getElementById("care-quiz-close");
    if (closeBtn) closeBtn.addEventListener("click", close);

    var backdrop = document.getElementById("care-quiz-backdrop");
    if (backdrop) backdrop.addEventListener("click", close);

    var startBtn = document.querySelector("[data-next='1']");
    if (startBtn) startBtn.addEventListener("click", function() { showStep(1); });

    var restartBtn = document.getElementById("care-quiz-restart");
    if (restartBtn) restartBtn.addEventListener("click", reset);

    var finishBtn = document.getElementById("care-quiz-finish");
    if (finishBtn) finishBtn.addEventListener("click", close);

    document.querySelectorAll(".care-quiz-option").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var q = parseInt(btn.dataset.q);
        answers[q] = btn.dataset.val;

        // Highlight selected
        document.querySelectorAll("[data-q='" + q + "']").forEach(function(b) {
          b.classList.remove("selected");
        });
        btn.classList.add("selected");

        // Kurze Pause, dann weiter
        setTimeout(function() {
          if (q < totalQuestions) {
            showStep(q + 1);
          } else {
            showResult();
          }
        }, 350);
      });
    });
  }

  return { init: init, open: open };
})();

// ---- Recently Viewed ----
var CareRecentlyViewed = (function() {
  "use strict";
  var KEY = "care_recently_viewed";
  var MAX = 4;

  function load() {
    try { return JSON.parse(localStorage.getItem(KEY)) || []; }
    catch (e) { return []; }
  }

  function track(product) {
    var items = load().filter(function(i) { return String(i.id) !== String(product.id); });
    items.unshift(product);
    if (items.length > MAX) items = items.slice(0, MAX);
    localStorage.setItem(KEY, JSON.stringify(items));
  }

  function render() {
    var section = document.getElementById("care-recently-viewed");
    var grid    = document.getElementById("care-recently-viewed-grid");
    if (!section || !grid) return;

    var items = load();
    if (items.length === 0) return;

    section.style.display = "block";

    var html = "";
    items.forEach(function(item) {
      html += "<div class='small-12 medium-6 large-3 column'>";
      html += "<div class='care-recent-card'>";
      html += "<div class='care-recent-image'><span class='care-recent-emoji'>" + (item.emoji || "🧴") + "</span></div>";
      html += "<div class='care-recent-body'>";
      html += "<h4 class='care-recent-name'>" + item.name + "</h4>";
      html += "<span class='care-recent-price'>" + item.price + "</span>";
      html += "<a href='" + item.url + "' class='care-btn-outline care-recent-link'>Ansehen</a>";
      html += "</div></div></div>";
    });
    grid.innerHTML = html;
  }

  function init() { render(); }

  return { init: init, track: track };
})();

// ---- Produktvergleich ----
var CareCompare = (function() {
  "use strict";
  var KEY = "care_compare";
  var MAX = 3;

  function load() {
    try { return JSON.parse(localStorage.getItem(KEY)) || []; }
    catch(e) { return []; }
  }

  function save(items) { localStorage.setItem(KEY, JSON.stringify(items)); }

  function showToast(msg) {
    var toast = document.getElementById("care-toast");
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add("visible");
    clearTimeout(toast._timer);
    toast._timer = setTimeout(function() { toast.classList.remove("visible"); }, 3000);
  }

  function refreshButtons() {
    document.querySelectorAll(".care-compare-btn").forEach(function(btn) {
      var on = load().some(function(i) { return String(i.id) === String(btn.dataset.productId); });
      btn.classList.toggle("active", on);
      btn.querySelector(".care-compare-label").textContent = on ? "✓ Im Vergleich" : "⇌ Vergleichen";
    });
  }

  function refreshBar() {
    var bar = document.getElementById("care-compare-bar");
    if (!bar) return;
    var items = load();
    if (items.length === 0) { bar.classList.remove("visible"); return; }
    bar.classList.add("visible");

    var miniEl = document.getElementById("care-compare-bar-items");
    if (miniEl) {
      var html = "";
      items.forEach(function(p) {
        html += "<div class='care-cbar-item'>";
        html += "<span class='care-cbar-emoji'>" + (p.emoji || "🧴") + "</span>";
        html += "<span class='care-cbar-name'>" + p.name + "</span>";
        html += "<button class='care-cbar-remove' data-id='" + p.id + "'>✕</button>";
        html += "</div>";
      });
      miniEl.innerHTML = html;
      miniEl.querySelectorAll(".care-cbar-remove").forEach(function(btn) {
        btn.addEventListener("click", function() {
          save(load().filter(function(i) { return String(i.id) !== btn.dataset.id; }));
          refreshBar(); refreshButtons();
        });
      });
    }

    var countEl = document.getElementById("care-cbar-count");
    if (countEl) countEl.textContent = items.length + " / " + MAX + " ausgewählt";

    var nowBtn = document.getElementById("care-compare-now");
    if (nowBtn) nowBtn.disabled = items.length < 2;
  }

  function toggle(product) {
    var items = load();
    var idx = items.findIndex(function(i) { return String(i.id) === String(product.id); });
    if (idx > -1) {
      items.splice(idx, 1);
    } else {
      if (items.length >= MAX) { showToast("⚠️ Maximal " + MAX + " Produkte vergleichen"); return; }
      items.push(product);
    }
    save(items);
    refreshBar();
    refreshButtons();
  }

  function openModal() {
    var items = load();
    if (items.length < 2) { showToast("⚠️ Bitte mindestens 2 Produkte auswählen"); return; }

    var modal = document.getElementById("care-compare-modal");
    if (!modal) return;

    var ATTRS = [
      { key: "price",    label: "Preis" },
      { key: "rating",   label: "Bewertung" },
      { key: "reviews",  label: "Bewertungen" },
      { key: "category", label: "Kategorie" },
      { key: "badge",    label: "Auszeichnung" },
      { key: "desc",     label: "Beschreibung" }
    ];

    var head = "<tr><th>Eigenschaft</th>";
    items.forEach(function(p) {
      head += "<th><span style='font-size:2.2rem;display:block'>" + (p.emoji || "🧴") + "</span>" +
              p.name + "<br><strong class='care-compare-th-price'>" + p.price + "</strong></th>";
    });
    head += "</tr>";

    var rows = "";
    ATTRS.forEach(function(attr) {
      rows += "<tr><td class='care-compare-attr'>" + attr.label + "</td>";
      items.forEach(function(p) {
        var val = p[attr.key] || "–";
        if (attr.key === "rating") {
          val = "★".repeat(Math.round(parseFloat(val))) + "☆".repeat(5 - Math.round(parseFloat(val))) + " " + val;
        }
        rows += "<td>" + val + "</td>";
      });
      rows += "</tr>";
    });

    var tbl = document.getElementById("care-compare-table-body");
    if (tbl) tbl.innerHTML = head + rows;

    modal.classList.add("open");
    document.getElementById("care-compare-backdrop").classList.add("open");
    document.body.style.overflow = "hidden";
  }

  function closeModal() {
    var modal = document.getElementById("care-compare-modal");
    if (modal) modal.classList.remove("open");
    var bd = document.getElementById("care-compare-backdrop");
    if (bd) bd.classList.remove("open");
    document.body.style.overflow = "";
  }

  function init() {
    document.querySelectorAll(".care-compare-btn").forEach(function(btn) {
      if (btn._compareBound) return;
      btn._compareBound = true;
      btn.addEventListener("click", function(e) {
        e.preventDefault();
        toggle({
          id: btn.dataset.productId,
          name: btn.dataset.productName,
          price: btn.dataset.productPrice,
          emoji: btn.dataset.productEmoji,
          rating: btn.dataset.productRating,
          reviews: btn.dataset.productReviews,
          category: btn.dataset.productCategory,
          badge: btn.dataset.productBadge || "–",
          desc: btn.dataset.productDesc
        });
      });
    });

    var nowBtn = document.getElementById("care-compare-now");
    if (nowBtn) nowBtn.addEventListener("click", openModal);

    var clearBtn = document.getElementById("care-compare-clear");
    if (clearBtn) clearBtn.addEventListener("click", function() { save([]); refreshBar(); refreshButtons(); });

    var closeBtn = document.getElementById("care-compare-modal-close");
    if (closeBtn) closeBtn.addEventListener("click", closeModal);

    var bd = document.getElementById("care-compare-backdrop");
    if (bd) bd.addEventListener("click", closeModal);

    refreshBar();
    refreshButtons();
  }

  return { init: init };
})();

// ---- Erweiterte Filter ----
var CareAdvancedFilter = (function() {
  "use strict";
  var minPrice = 0, maxPrice = 9999, minRating = 0, onlyBadge = false;

  function applyFilters() {
    var query = (document.getElementById("care-search-input") || {}).value || "";
    query = query.toLowerCase().trim();
    var sort  = (document.getElementById("care-sort-select") || {}).value || "default";
    var cards = Array.from(document.querySelectorAll(".care-product-col"));
    var clearBtn = document.getElementById("care-search-clear");
    if (clearBtn) clearBtn.style.display = query ? "inline-block" : "none";

    var visible = [];
    cards.forEach(function(card) {
      var name   = (card.dataset.name || "").toLowerCase();
      var price  = parseInt(card.dataset.price) || 0;
      var rating = parseFloat(card.dataset.rating) || 0;
      var badge  = (card.dataset.badge || "").trim();

      var ok = (!query || name.indexOf(query) > -1) &&
               price >= minPrice * 100 && price <= maxPrice * 100 &&
               rating >= minRating &&
               (!onlyBadge || badge !== "");

      card.style.display = ok ? "" : "none";
      if (ok) visible.push(card);
    });

    if (sort !== "default" && visible.length > 1) {
      var grid = document.getElementById("care-products-grid");
      if (grid) {
        visible.sort(function(a, b) {
          if (sort === "price-asc")    return parseInt(a.dataset.price)  - parseInt(b.dataset.price);
          if (sort === "price-desc")   return parseInt(b.dataset.price)  - parseInt(a.dataset.price);
          if (sort === "rating-desc")  return parseFloat(b.dataset.rating) - parseFloat(a.dataset.rating);
          if (sort === "reviews-desc") return parseInt(b.dataset.reviews) - parseInt(a.dataset.reviews);
          if (sort === "name-asc")     return (a.dataset.name || "").localeCompare(b.dataset.name || "");
          return 0;
        });
        visible.forEach(function(card) { grid.appendChild(card); });
      }
    }

    var countEl = document.getElementById("care-results-count");
    if (countEl) countEl.textContent = visible.length + " Produkte";
    var noEl = document.getElementById("care-no-results");
    if (noEl) noEl.style.display = visible.length === 0 ? "block" : "none";
    updateBadgeCount();
  }

  function updateBadgeCount() {
    var n = (minRating > 0 ? 1 : 0) + (onlyBadge ? 1 : 0) +
            (minPrice > 0 || maxPrice < 9999 ? 1 : 0);
    var badge = document.getElementById("care-filter-badge");
    if (badge) { badge.textContent = n; badge.style.display = n > 0 ? "inline-block" : "none"; }
    var toggleBtn = document.getElementById("care-filter-toggle");
    if (toggleBtn) toggleBtn.classList.toggle("has-filters", n > 0);
  }

  function init() {
    var panel = document.getElementById("care-advanced-filter-panel");
    if (!panel) return;

    var toggleBtn = document.getElementById("care-filter-toggle");
    if (toggleBtn) toggleBtn.addEventListener("click", function() {
      panel.classList.toggle("open");
    });

    var minP = document.getElementById("care-filter-min-price");
    var maxP = document.getElementById("care-filter-max-price");
    var minValEl = document.getElementById("care-filter-min-val");
    var maxValEl = document.getElementById("care-filter-max-val");

    if (minP) minP.addEventListener("input", function() {
      minPrice = parseFloat(this.value) || 0;
      if (minValEl) minValEl.textContent = minPrice > 0 ? minPrice + " €" : "0 €";
      applyFilters();
    });
    if (maxP) maxP.addEventListener("input", function() {
      maxPrice = parseFloat(this.value) || 9999;
      if (maxValEl) maxValEl.textContent = maxPrice < 9999 ? maxPrice + " €" : "∞";
      applyFilters();
    });

    document.querySelectorAll(".care-rating-filter-btn").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var val = parseInt(btn.dataset.rating);
        if (minRating === val) {
          minRating = 0;
          document.querySelectorAll(".care-rating-filter-btn").forEach(function(b) { b.classList.remove("active"); });
        } else {
          minRating = val;
          document.querySelectorAll(".care-rating-filter-btn").forEach(function(b) {
            b.classList.toggle("active", parseInt(b.dataset.rating) <= val);
          });
        }
        applyFilters();
      });
    });

    var badgeTog = document.getElementById("care-filter-badge-toggle");
    if (badgeTog) badgeTog.addEventListener("change", function() { onlyBadge = this.checked; applyFilters(); });

    var resetBtn = document.getElementById("care-filter-reset-btn");
    if (resetBtn) resetBtn.addEventListener("click", function() {
      minPrice = 0; maxPrice = 9999; minRating = 0; onlyBadge = false;
      if (minP) { minP.value = ""; if (minValEl) minValEl.textContent = "0 €"; }
      if (maxP) { maxP.value = ""; if (maxValEl) maxValEl.textContent = "∞"; }
      document.querySelectorAll(".care-rating-filter-btn").forEach(function(b) { b.classList.remove("active"); });
      if (badgeTog) badgeTog.checked = false;
      var si = document.getElementById("care-search-input");
      var ss = document.getElementById("care-sort-select");
      if (si) si.value = "";
      if (ss) ss.value = "default";
      applyFilters();
    });

    // Hook existing search + sort
    var si = document.getElementById("care-search-input");
    var ss = document.getElementById("care-sort-select");
    var clearBtn = document.getElementById("care-search-clear");
    var rstBtn = document.getElementById("care-btn-reset-search");
    if (si) si.addEventListener("input", applyFilters);
    if (ss) ss.addEventListener("change", applyFilters);
    if (clearBtn) clearBtn.addEventListener("click", function() { si.value = ""; applyFilters(); si.focus(); });
    if (rstBtn) rstBtn.addEventListener("click", function() {
      if (si) si.value = ""; if (ss) ss.value = "default"; applyFilters();
    });
  }

  return { init: init };
})();

// ---- FAQ-Accordion ----
var CareFAQ = (function() {
  "use strict";
  function init() {
    document.querySelectorAll(".care-faq-question").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var item = btn.closest(".care-faq-item");
        var wasOpen = item.classList.contains("open");
        document.querySelectorAll(".care-faq-item").forEach(function(i) { i.classList.remove("open"); });
        if (!wasOpen) item.classList.add("open");
      });
    });
  }
  return { init: init };
})();

// ---- Bootstrap ----
$(document).on("turbolinks:load", function() {
  CareCart.init();
  CareWishlist.init();
  // Advanced filter supersedes basic search when panel is present
  if (document.getElementById("care-advanced-filter-panel")) {
    CareAdvancedFilter.init();
  } else {
    CareSearch.init();
  }
  CareSaleCountdown.init();
  CareScrollTop.init();
  CarePromoBar.init();
  CareCoupon.init();
  CareReviewForm.init();
  CareQuiz.init();
  CareRecentlyViewed.init();
  CareCompare.init();
  CareFAQ.init();
});
