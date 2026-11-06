App.Studio.utils.YOUTUBE_HOSTS = ["youtube.com", "youtube-nocookie.com", "youtu.be"];
App.Studio.utils.YOUTUBE_VIDEO_ID_PATTERN = /^[A-Za-z0-9_-]{11}$/;
App.Studio.utils.YOUTUBE_EMBED_BASE_URL = "https://www.youtube-nocookie.com/embed/";

// Accepts any link form an editor is likely to paste (watch, youtu.be,
// shorts, live, embed) and returns the video id plus an optional start
// time, or null when the input names no real video. Template placeholders
// such as ".../embed/VIDEO-ID" are not 11-character ids, so they read as
// "no video set".
App.Studio.utils.parseYoutubeUrl = function(input) {
  const url = App.Studio.utils.parseUrlLeniently(input);

  if (!url) return null

  const host = App.Studio.utils.youtubeHostFor(url);

  if (!host) return null

  const videoId = App.Studio.utils.youtubeVideoIdFrom(url, host);

  if (!App.Studio.utils.YOUTUBE_VIDEO_ID_PATTERN.test(videoId || "")) return null

  return {
    videoId: videoId,
    startSeconds: App.Studio.utils.youtubeStartSecondsFrom(url)
  }
}

App.Studio.utils.isYoutubeEmbed = function(input) {
  const url = App.Studio.utils.parseUrlLeniently(input);

  return Boolean(url && App.Studio.utils.youtubeHostFor(url))
}

App.Studio.utils.youtubeEmbedUrl = function(videoId, startSeconds) {
  const embedUrl = `${App.Studio.utils.YOUTUBE_EMBED_BASE_URL}${encodeURIComponent(videoId)}`;

  return startSeconds ? `${embedUrl}?start=${startSeconds}` : embedUrl
}

App.Studio.utils.parseUrlLeniently = function(input) {
  const trimmed = (input || "").trim();

  if (!trimmed) return null

  const withScheme = /^[a-z][a-z0-9+.-]*:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;

  try {
    const url = new URL(withScheme);

    return ["http:", "https:"].includes(url.protocol) ? url : null
  } catch (_error) {
    return null
  }
}

App.Studio.utils.youtubeHostFor = function(url) {
  const host = url.hostname.toLowerCase().replace(/^(www|m)\./, "");

  return App.Studio.utils.YOUTUBE_HOSTS.includes(host) ? host : null
}

App.Studio.utils.youtubeVideoIdFrom = function(url, host) {
  if (host === "youtu.be") return url.pathname.split("/")[1]
  if (url.pathname === "/watch") return url.searchParams.get("v")

  const pathMatch = url.pathname.match(/^\/(embed|shorts|live|v)\/([^/]+)/);

  return pathMatch ? pathMatch[2] : null
}

// "t" or "start" as plain seconds ("90", "90s") or with units ("1m30s").
App.Studio.utils.youtubeStartSecondsFrom = function(url) {
  const value = url.searchParams.get("start") || url.searchParams.get("t");

  if (!value) return null

  const unitsMatch = value.match(/^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s?)?$/);

  if (!unitsMatch) return null

  const [, hours, minutes, seconds] = unitsMatch;
  const totalSeconds = Number(hours || 0) * 3600 + Number(minutes || 0) * 60 + Number(seconds || 0);

  return totalSeconds > 0 ? totalSeconds : null
}
