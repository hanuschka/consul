// Care Products – Shopping Cart (localStorage-based)
var CareCart = (function() {
  "use strict";

  var STORAGE_KEY = "care_cart";

  function load() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY)) || [];
    } catch (e) {
      return [];
    }
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
      items.push({
        id: product.id,
        name: product.name,
        price: product.price,
        emoji: product.emoji,
        qty: product.qty || 1
      });
    }
    save(items);
    updateBadge();
    showToast(product.name);
  }

  function remove(productId) {
    var items = load().filter(function(i) { return i.id !== productId; });
    save(items);
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
    badge.style.display = count > 0 ? "inline-block" : "none";
  }

  function showToast(name) {
    var toast = document.getElementById("care-toast");
    if (!toast) return;
    toast.textContent = "✓ \"" + name + "\" wurde hinzugefügt";
    toast.classList.add("visible");
    clearTimeout(toast._timer);
    toast._timer = setTimeout(function() {
      toast.classList.remove("visible");
    }, 3000);
  }

  function renderCartPanel() {
    var panel = document.getElementById("care-cart-panel-items");
    if (!panel) return;
    var items = load();

    if (items.length === 0) {
      panel.innerHTML = '<p class="care-cart-empty">Ihr Warenkorb ist leer.</p>';
      document.getElementById("care-cart-total").textContent = "0,00 €";
      return;
    }

    var html = "";
    var total = 0;

    items.forEach(function(item) {
      var priceNum = parseFloat(item.price.replace(",", ".").replace(" €", "")) || 0;
      var lineTotal = priceNum * (item.qty || 1);
      total += lineTotal;

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
    document.getElementById("care-cart-total").textContent =
      total.toFixed(2).replace(".", ",") + " €";

    panel.querySelectorAll(".care-cart-remove").forEach(function(btn) {
      btn.addEventListener("click", function() {
        remove(btn.dataset.id);
      });
    });
  }

  function togglePanel() {
    var panel = document.getElementById("care-cart-panel");
    if (!panel) return;
    panel.classList.toggle("open");
    if (panel.classList.contains("open")) renderCartPanel();
  }

  function init() {
    updateBadge();

    var trigger = document.getElementById("care-cart-trigger");
    if (trigger) {
      trigger.addEventListener("click", function(e) {
        e.preventDefault();
        togglePanel();
      });
    }

    var closeBtn = document.getElementById("care-cart-close");
    if (closeBtn) {
      closeBtn.addEventListener("click", function() {
        document.getElementById("care-cart-panel").classList.remove("open");
      });
    }

    // Warenkorb-Buttons auf der Indexseite
    document.querySelectorAll("[data-care-add-cart]").forEach(function(btn) {
      btn.addEventListener("click", function() {
        add({
          id: btn.dataset.productId,
          name: btn.dataset.productName,
          price: btn.dataset.productPrice,
          emoji: btn.dataset.productEmoji,
          qty: 1
        });
        btn.textContent = "✓ Hinzugefügt!";
        btn.style.background = "#357a62";
        setTimeout(function() {
          btn.textContent = "In den Warenkorb";
          btn.style.background = "";
        }, 2000);
      });
    });
  }

  return { add: add, remove: remove, load: load, init: init };
})();

$(document).on("turbolinks:load", function() {
  CareCart.init();
});
