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
  toggle.textContent = paused ? "播放预览" : "暂停预览";
});
