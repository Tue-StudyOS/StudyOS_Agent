const REPOSITORY = "Tue-StudyOS/StudyOS_Agent";
const RELEASES_URL = `https://github.com/${REPOSITORY}/releases`;
const LATEST_RELEASE_API = `https://api.github.com/repos/${REPOSITORY}/releases/latest`;

const PLATFORM_MATCHERS = {
  android: [/android|apk/i, /\.apk$/i],
  macos: [/macos|darwin|osx/i, /\.zip$/i],
  windows: [/windows|win/i, /\.zip$/i],
  linux: [/linux/i, /\.tar\.gz$/i],
  web: [/web/i, /\.zip$/i],
};

const PLATFORM_LABELS = {
  android: "Android",
  macos: "macOS",
  windows: "Windows",
  linux: "Linux",
  web: "Web",
};

const statusElement = document.querySelector("#release-status");
const primaryDownload = document.querySelector("#primary-download");

initDownloadPage();

async function initDownloadPage() {
  const platform = detectPlatform();

  try {
    const release = await fetchLatestRelease();
    const assetsByPlatform = groupAssetsByPlatform(release.assets ?? []);
    renderPlatformCards(assetsByPlatform);
    renderPrimaryDownload(platform, assetsByPlatform, release.html_url);
  } catch (error) {
    renderReleaseFallback(error);
  }
}

function detectPlatform() {
  const platform = navigator.userAgentData?.platform || navigator.platform || navigator.userAgent || "";
  if (/android/i.test(platform)) {
    return "android";
  }
  return "web";
}

async function fetchLatestRelease() {
  const response = await fetch(LATEST_RELEASE_API, {
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!response.ok) {
    throw new Error(`GitHub returned ${response.status}`);
  }
  return response.json();
}

function groupAssetsByPlatform(assets) {
  return Object.fromEntries(
    Object.keys(PLATFORM_MATCHERS).map((platform) => [
      platform,
      assets.find((asset) => assetMatchesPlatform(asset.name, platform)) ?? null,
    ])
  );
}

function assetMatchesPlatform(name, platform) {
  const [nameMatcher, extensionMatcher] = PLATFORM_MATCHERS[platform];
  return nameMatcher.test(name) && extensionMatcher.test(name);
}

function renderPlatformCards(assetsByPlatform) {
  Object.entries(assetsByPlatform).forEach(([platform, asset]) => {
    const card = document.querySelector(`[data-platform-card="${platform}"]`);
    const link = card?.querySelector("a");
    if (!card || !link || !asset) {
      return;
    }
    card.dataset.available = "true";
    link.href = asset.browser_download_url;
    link.textContent = "Download";
  });
}

function renderPrimaryDownload(platform, assetsByPlatform, releaseUrl) {
  const asset = assetsByPlatform[platform];
  if (!asset) {
    statusElement.textContent = `No ${PLATFORM_LABELS[platform]} build is attached to the latest release yet.`;
    primaryDownload.textContent = "Open latest release";
    primaryDownload.href = releaseUrl || RELEASES_URL;
    primaryDownload.classList.remove("disabled");
    primaryDownload.removeAttribute("aria-disabled");
    return;
  }

  statusElement.textContent = `Latest ${PLATFORM_LABELS[platform]} build found.`;
  primaryDownload.textContent = `Download for ${PLATFORM_LABELS[platform]}`;
  primaryDownload.href = asset.browser_download_url;
  primaryDownload.classList.remove("disabled");
  primaryDownload.removeAttribute("aria-disabled");
}

function renderReleaseFallback(error) {
  statusElement.textContent = `No release download is available yet. ${error.message}`;
  primaryDownload.textContent = "Open GitHub releases";
  primaryDownload.href = RELEASES_URL;
  primaryDownload.classList.remove("disabled");
  primaryDownload.removeAttribute("aria-disabled");
}
