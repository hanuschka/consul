App.htmlTemplateUtils = {}

/**
 * Fills HTML template with data by replacing {{key}} placeholders
 *
 * @param {string} template - HTML template string with {{key}} placeholders
 * @param {object} data - Data object with values to fill
 * @returns {string} Filled HTML string
 *
 * Supports nested properties with dot notation: {{ user.name }}
 * Returns empty string for missing properties
 *
 * @example
 * const template = '<div class="{{cssClass}}">{{user.name}}</div>';
 * const data = { cssClass: 'active', user: { name: 'John' } };
 * const html = App.htmlTemplateUtils.fillTemplate(template, data);
 * // Result: '<div class="active">John</div>'
 */
App.htmlTemplateUtils.fillTemplate = function(template, data) {
  return template.replace(/{{\s*([\w.]+)\s*}}/g, (_, key) => {
    return key.split('.').reduce((obj, k) => obj && obj[k], data) || '';
  });
}
