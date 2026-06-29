App.Studio.utils.debounce = function(func, wait) {
  let timeout;
  return function(...args) {
    const context = this;
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(context, args), wait);
  };
}

App.Studio.utils.throttle = function(func, wait) {
  let lastTime = 0;
  return function(...args) {
    const context = this;
    const now = Date.now();
    if (now - lastTime >= wait) {
      lastTime = now;
      func.apply(context, args);
    }
  };
}

