import { Controller } from '@hotwired/stimulus';
import Pickr from '@simonwep/pickr';
import { getBrandColor } from '../../lib/map_adapters/map_utils';

export default class extends Controller {
  static targets = [ 'picker', 'colorInput' ];

  connect() {
    this.pickr = new Pickr({
      el: this.pickerTarget,
      container: 'body',
      theme: 'nano',
      lockOpacity: true,
      comparison: false,
      default: this.colorInputTarget.value || getBrandColor(),
      position: 'bottom-end',
      components: {
        palette: true,
        preview: true,
        hue: true,
        interaction: {
          hex: true,
          input: true
        }
      }
    });

    this.pickr.on('change', (color, source, instance) => {
      const hexColor = color.toHEXA().toString();
      this.colorInputTarget.value = hexColor;
    });
  }
}

