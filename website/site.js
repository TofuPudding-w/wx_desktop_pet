"use strict";
const toggle = document.querySelector("#motion");
const scene = document.querySelector(".scene");
const preference = window.matchMedia("(prefers-reduced-motion: reduce)");
function syncMotion() { toggle.hidden = preference.matches; }
syncMotion();
preference.addEventListener("change", syncMotion);
toggle.addEventListener("click", () => {
  const paused = scene.classList.toggle("paused");
  toggle.setAttribute("aria-pressed", String(paused));
  toggle.textContent = document.documentElement.lang === "en"
    ? (paused ? "Play preview" : "Pause preview")
    : (paused ? "播放预览" : "暂停预览");
});

for (const link of document.querySelectorAll("[data-language]")) {
  if (link.dataset.language === (document.documentElement.lang === "en" ? "en" : "zh")) link.setAttribute("aria-current", "page");
}
