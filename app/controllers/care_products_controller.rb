class CareProductsController < ApplicationController
  skip_authorization_check

  CATEGORIES = [
    {
      id: "hautpflege",
      name: "Hautpflege",
      icon: "💧",
      description: "Cremes, Lotionen und Seren für strahlende Haut"
    },
    {
      id: "haarpflege",
      name: "Haarpflege",
      icon: "✨",
      description: "Shampoos, Spülungen und Haarkuren für gesundes Haar"
    },
    {
      id: "koerperpflege",
      name: "Körperpflege",
      icon: "🧴",
      description: "Duschgele, Badeöle und Körperlotionen"
    },
    {
      id: "mundpflege",
      name: "Mundpflege",
      icon: "🦷",
      description: "Zahnpasten, Mundspülungen und Zahnbürsten"
    },
    {
      id: "sonnenpflege",
      name: "Sonnenpflege",
      icon: "☀️",
      description: "Sonnencreme, After-Sun und Selbstbräuner"
    },
    {
      id: "babypflege",
      name: "Babypflege",
      icon: "🌸",
      description: "Sanfte Pflegeprodukte für die zarte Babyhaut"
    }
  ].freeze

  PRODUCTS = [
    {
      id: 1,
      name: "Feuchtigkeitscreme Premium",
      category: "hautpflege",
      price: "24,99 €",
      price_cents: 2499,
      rating: 4.8,
      reviews: 142,
      badge: "Bestseller",
      description: "Intensive Feuchtigkeitspflege mit Hyaluron und Vitamin E für 24h Feuchtigkeit."
    },
    {
      id: 2,
      name: "Nährendes Haarshampoo",
      category: "haarpflege",
      price: "12,49 €",
      price_cents: 1249,
      rating: 4.6,
      reviews: 98,
      badge: "Neu",
      description: "Pflegendes Shampoo mit Keratin und Arganöl für glänzendes, gesundes Haar."
    },
    {
      id: 3,
      name: "Verwöhn-Duschgel",
      category: "koerperpflege",
      price: "8,99 €",
      price_cents: 899,
      rating: 4.5,
      reviews: 231,
      badge: nil,
      description: "Cremiges Duschgel mit Mandel- und Jojobaöl für samtweiche Haut."
    },
    {
      id: 4,
      name: "Whitening Zahnpasta",
      category: "mundpflege",
      price: "6,99 €",
      price_cents: 699,
      rating: 4.7,
      reviews: 187,
      badge: "Bestseller",
      description: "Aufhellende Zahnpasta mit natürlichem Aktivkohle-Komplex."
    },
    {
      id: 5,
      name: "Sonnenschutz LSF 50",
      category: "sonnenpflege",
      price: "18,99 €",
      price_cents: 1899,
      rating: 4.9,
      reviews: 304,
      badge: "Top-Bewertet",
      description: "Leichte Sonnencreme mit hohem UV-Schutz und feuchtigkeitsspendender Formel."
    },
    {
      id: 6,
      name: "Baby Pflegelotion",
      category: "babypflege",
      price: "9,99 €",
      price_cents: 999,
      rating: 4.8,
      reviews: 156,
      badge: "Sanfte Formel",
      description: "Zarte Pflegelotion ohne Parfüm und Farbstoffe, dermatologisch getestet."
    },
    {
      id: 7,
      name: "Anti-Aging Serum",
      category: "hautpflege",
      price: "39,99 €",
      price_cents: 3999,
      rating: 4.7,
      reviews: 89,
      badge: "Premium",
      description: "Hochkonzentriertes Serum mit Retinol und Peptiden gegen Falten."
    },
    {
      id: 8,
      name: "Intensive Haarkur",
      category: "haarpflege",
      price: "16,99 €",
      price_cents: 1699,
      rating: 4.6,
      reviews: 73,
      badge: "Neu",
      description: "Tief wirkende Haarkur mit Sheabutter und Arganöl für trockenes Haar."
    }
  ].freeze

  BUNDLES = [
    {
      id: 1,
      name: "Starter Pflege-Set",
      icon: "🌿",
      description: "Die perfekte Einführung in natürliche Pflege – alles was Sie zum Start brauchen.",
      product_ids: [1, 3, 4],
      original_price: "40,97 €",
      bundle_price: "29,99 €",
      savings: "10,98 €",
      badge: "Beliebt"
    },
    {
      id: 2,
      name: "Premium Hautpflege-Paket",
      icon: "✨",
      description: "Das Beste für Ihre Haut: Anti-Aging Serum und intensive Feuchtigkeitspflege kombiniert.",
      product_ids: [1, 7, 5],
      original_price: "83,97 €",
      bundle_price: "59,99 €",
      savings: "23,98 €",
      badge: "Bestseller"
    },
    {
      id: 3,
      name: "Familienpaket Rundumpflege",
      icon: "🌸",
      description: "Für die ganze Familie: von Babypflege bis Haarpflege – alle optimal versorgt.",
      product_ids: [6, 3, 8],
      original_price: "35,97 €",
      bundle_price: "24,99 €",
      savings: "10,98 €",
      badge: "Neu"
    }
  ].freeze

  SALE_PRODUCTS = [
    {
      id: 1,
      product_ref: 3,
      name: "Verwöhn-Duschgel",
      category: "koerperpflege",
      icon: "🧴",
      original_price: "8,99 €",
      sale_price: "5,99 €",
      discount: 33
    },
    {
      id: 2,
      product_ref: 2,
      name: "Nährendes Haarshampoo",
      category: "haarpflege",
      icon: "✨",
      original_price: "12,49 €",
      sale_price: "8,99 €",
      discount: 28
    },
    {
      id: 3,
      product_ref: 4,
      name: "Whitening Zahnpasta",
      category: "mundpflege",
      icon: "🦷",
      original_price: "6,99 €",
      sale_price: "4,49 €",
      discount: 36
    },
    {
      id: 4,
      product_ref: 6,
      name: "Baby Pflegelotion",
      category: "babypflege",
      icon: "🌸",
      original_price: "9,99 €",
      sale_price: "6,99 €",
      discount: 30
    }
  ].freeze

  def index
    @categories = CATEGORIES
    @all_products = PRODUCTS
    @sale_products = SALE_PRODUCTS
    @bundles = BUNDLES

    if params[:category].present?
      @selected_category = params[:category]
      @filtered_products = PRODUCTS.select { |p| p[:category] == @selected_category }
      @featured_products = @filtered_products
    else
      @featured_products = PRODUCTS
    end
  end

  def show
    @product = PRODUCTS.find { |p| p[:id] == params[:id].to_i }
    head :not_found unless @product
  end
end
