"use strict";

const visor = document.querySelector("#visor");
document.querySelectorAll("[data-imagen]").forEach((boton) => {
  boton.addEventListener("click", () => {
    visor.querySelector("img").src = boton.dataset.imagen;
    visor.querySelector("img").alt = boton.querySelector("img").alt;
    visor.querySelector("p").textContent = boton.dataset.pie;
    visor.showModal();
  });
});
document.querySelector(".cerrar-visor").addEventListener("click", () => visor.close());
visor.addEventListener("click", (evento) => {
  if (evento.target === visor) {
    const caja = visor.getBoundingClientRect();
    if (evento.clientX < caja.left || evento.clientX > caja.right || evento.clientY < caja.top || evento.clientY > caja.bottom) visor.close();
  }
});

async function actualizarVersion() {
  try {
    const respuesta = await fetch("version.json", { cache: "no-store" });
    if (!respuesta.ok) throw new Error("No se ha recibido la versión.");
    const datos = await respuesta.json();
    if (typeof datos.version !== "string" || !/^\d+\.\d+\.\d+$/.test(datos.version)) throw new Error("Versión inválida.");
    document.querySelectorAll("[data-version]").forEach((elemento) => { elemento.textContent = `Alfa ${datos.version}`; });
    const paquete = datos.windows;
    if (paquete && typeof paquete.url === "string") {
      const destino = new URL(paquete.url, location.href);
      if (!['https:', 'http:'].includes(destino.protocol)) throw new Error("Enlace de descarga inválido.");
      document.querySelectorAll("[data-paquete]").forEach((enlace) => { enlace.href = destino.href; });
      if (Number.isFinite(paquete.size_bytes)) document.querySelector("[data-tamano]").textContent = `${(paquete.size_bytes / 1024 ** 3).toLocaleString("es", { maximumFractionDigits: 2 })} GB · ZIP completo, sin instalación.`;
      if (/^[a-f0-9]{64}$/i.test(paquete.sha256)) document.querySelector("[data-hash]").textContent = paquete.sha256;
    }
  } catch (_error) {
    document.querySelector("[data-estado]").textContent = "Puedes usar los enlaces directos de descarga.";
  }
}
actualizarVersion();
