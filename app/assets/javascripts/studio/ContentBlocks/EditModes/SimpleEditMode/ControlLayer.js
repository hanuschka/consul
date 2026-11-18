// Layer that simple edit mode appends to a content block's studio wrapper to
// carry controls laid over the block's content (YouTube links, progress
// bars). It sits outside the saved content, so nothing has to be stripped
// before a save.
//
// Observers call the owner's onSync while the block changes: typing, list
// items added, removed or sorted, resizes, and whatever else the owner's
// mutationOptions ask for. A block deleted while in simple edit mode never
// gets its toggle-off call, so the owner's onDisconnect is called instead.
App.Studio.ContentBlocks.SimpleEditMode.ControlLayer = {
  attach(contentBlock, options) {
    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(contentBlock);
    const element = document.createElement("div");
    element.className = `${options.className} js-studio-hide-on-preview`;
    wrapper.appendChild(element);

    const layer = {
      element: element,
      contentBlock: contentBlock,
      onSync: options.onSync,
      onDisconnect: options.onDisconnect,
      frameRequest: null
    };

    layer.scheduleSync = () => this.scheduleSync(layer);
    layer.resizeObserver = new ResizeObserver(layer.scheduleSync);
    layer.resizeObserver.observe(contentBlock);
    layer.resizeObserver.observe(wrapper);
    layer.mutationObserver = new MutationObserver(layer.scheduleSync);
    layer.mutationObserver.observe(contentBlock, options.mutationOptions);
    window.addEventListener("resize", layer.scheduleSync);

    return layer
  },

  // For elements that can change size while the block keeps its own, such as
  // a flex item next to text being typed.
  observeResize(layer, element) {
    layer.resizeObserver.observe(element);
  },

  unobserveResize(layer, element) {
    layer.resizeObserver.unobserve(element);
  },

  detach(layer) {
    layer.resizeObserver.disconnect();
    layer.mutationObserver.disconnect();
    window.removeEventListener("resize", layer.scheduleSync);
    cancelAnimationFrame(layer.frameRequest);
    layer.element.remove();
  },

  // Observers fire in bursts (one per typed character, several per sort);
  // one sync per frame is enough to keep the controls in place.
  scheduleSync(layer) {
    if (layer.frameRequest) return

    if (!layer.contentBlock.isConnected) {
      layer.onDisconnect();

      return
    }

    layer.frameRequest = requestAnimationFrame(() => {
      layer.frameRequest = null;
      layer.onSync();
    });
  }
};
