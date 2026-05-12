(function() {
  "use strict";

  const PARAM_KEYS = [
    "search",
    "extension",
    "size_min_mb",
    "size_max_mb",
    "created_from",
    "created_to",
    "updated_from",
    "updated_to",
    "imageable_type",
    "documentable_type",
    "sort",
    "type",
    "page",
    "projekt_id"
  ];

  const FORM_INPUTS = [
    { key: "search", selector: ".js-fm-filter-search" },
    { key: "extension", selector: ".js-fm-filter-extension" },
    { key: "size_min_mb", selector: ".js-fm-filter-size-min", coerce: "integer" },
    { key: "size_max_mb", selector: ".js-fm-filter-size-max", coerce: "integer" },
    { key: "created_from", selector: ".js-fm-filter-created-from" },
    { key: "created_to", selector: ".js-fm-filter-created-to" },
    { key: "updated_from", selector: ".js-fm-filter-updated-from" },
    { key: "updated_to", selector: ".js-fm-filter-updated-to" },
    { key: "imageable_type", selector: ".js-fm-filter-imageable-type" },
    { key: "documentable_type", selector: ".js-fm-filter-documentable-type" },
    { key: "sort", selector: ".js-fm-filter-sort" }
  ];

  const isBlank = (value) => {
    if (value === null || value === undefined) return true;
    if (typeof value === "string" && value.trim() === "") return true;
    return false;
  };

  const coerceInteger = (rawValue) => {
    const trimmed = String(rawValue).trim();

    if (trimmed === "") return null;
    if (!/^-?\d+$/.test(trimmed)) return null;

    return trimmed;
  };

  const readInputValue = (rootEl, entry) => {
    const input = rootEl.querySelector(entry.selector);

    if (!input) return null;

    const rawValue = input.value;

    if (isBlank(rawValue)) return null;

    if (entry.coerce === "integer") {
      return coerceInteger(rawValue);
    }

    return rawValue;
  };

  const writeInputValue = (rootEl, entry, value) => {
    const input = rootEl.querySelector(entry.selector);

    if (!input) return;

    input.value = value === null || value === undefined ? "" : value;
  };

  const entryForKey = (key) => FORM_INPUTS.find((entry) => entry.key === key);

  window.FilesFilterSerializer = {
    PARAM_KEYS: PARAM_KEYS,

    serializeForm(rootEl) {
      const params = {};

      FORM_INPUTS.forEach((entry) => {
        const value = readInputValue(rootEl, entry);

        if (value === null) return;

        params[entry.key] = value;
      });

      return params;
    },

    applyToForm(rootEl, params) {
      if (!params) return;

      PARAM_KEYS.forEach((key) => {
        if (!Object.prototype.hasOwnProperty.call(params, key)) return;

        const entry = entryForKey(key);

        if (!entry) return;

        writeInputValue(rootEl, entry, params[key]);
      });
    },

    urlForParams(basePath, params) {
      const query = new URLSearchParams();

      PARAM_KEYS.forEach((key) => {
        const value = params ? params[key] : null;

        if (isBlank(value)) return;

        query.append(key, value);
      });

      const queryString = query.toString();

      if (queryString === "") return basePath;

      return `${basePath}?${queryString}`;
    },

    parseUrlParams(searchString) {
      const input = searchString || "";
      const normalized = input.charAt(0) === "?" ? input.slice(1) : input;
      const query = new URLSearchParams(normalized);
      const params = {};

      PARAM_KEYS.forEach((key) => {
        if (!query.has(key)) return;

        params[key] = query.get(key);
      });

      return params;
    }
  };
}).call(this);
