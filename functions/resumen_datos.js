// Partes puras del resumen mensual inteligente (ver resumen.js): qué mes
// se puede pedir, los números del mes que se le pasan a la IA y la
// limpieza de lo que responde. Sin dependencias, para probarlo sin red.

const {claveDia} = require("./planes.js");

// México no tiene horario de verano desde 2022: UTC-6 todo el año.
const DESFASE_MEXICO_HORAS = 6;

function mesActual(ahora) {
  return claveDia(ahora).slice(0, 7);
}

/// Solo el mes en curso y los 11 anteriores, en formato "2026-11".
function mesValido(mes, ahora) {
  if (typeof mes !== "string" || !/^\d{4}-(0[1-9]|1[0-2])$/.test(mes)) return false;
  const [a, m] = mesActual(ahora).split("-").map(Number);
  const [y, n] = mes.split("-").map(Number);
  const diferencia = (a - y) * 12 + (m - n);
  return diferencia >= 0 && diferencia <= 11;
}

function mesAnterior(mes) {
  const [y, n] = mes.split("-").map(Number);
  return n === 1 ? `${y - 1}-12` : `${y}-${String(n - 1).padStart(2, "0")}`;
}

/// [desde, hasta) del mes en hora de México, como Date (UTC).
function rangoMes(mes) {
  const [y, n] = mes.split("-").map(Number);
  return {
    desde: new Date(Date.UTC(y, n - 1, 1, DESFASE_MEXICO_HORAS)),
    hasta: new Date(Date.UTC(y, n, 1, DESFASE_MEXICO_HORAS)),
  };
}

const redondear = (v) => Math.round(v * 100) / 100;

// Un "ingreso" en una categoría de gasto es un reembolso: ya resta del
// gasto de su categoría, así que no cuenta como ingreso real. Tampoco el
// pago de una tarjeta (es mover dinero propio).
const NO_SON_INGRESO = new Set([
  "Alimentación", "Transporte", "Vivienda", "Servicios", "Salud", "Ocio",
  "Compras", "Educación", "Ajuste", "Pago de tarjeta",
]);

/// Números de un mes con el mismo criterio que la app (ResumenGastos):
/// sin transferencias ni ajustes, y un reembolso resta de su categoría.
function agregarMes(transacciones, mes) {
  const {desde, hasta} = rangoMes(mes);
  const delMes = transacciones.filter((t) =>
    !t.transferenciaId && !t.libretaId && t.categoria !== "Ajuste" &&
    t.fecha >= desde && t.fecha < hasta && typeof t.monto === "number");

  const netoPorCategoria = {};
  let ingresos = 0;
  const gastos = [];
  for (const t of delMes) {
    const signo = t.tipo === "gasto" ? 1 : -1;
    netoPorCategoria[t.categoria] = (netoPorCategoria[t.categoria] || 0) + signo * t.monto;
    if (t.tipo === "ingreso" && !NO_SON_INGRESO.has(t.categoria)) ingresos += t.monto;
    if (t.tipo === "gasto") gastos.push(t);
  }
  const porCategoria = Object.entries(netoPorCategoria)
      .filter(([, v]) => v > 0.01)
      .sort((a, b) => b[1] - a[1])
      .map(([categoria, v]) => ({categoria, monto: redondear(v)}));
  const gastoTotal = redondear(porCategoria.reduce((a, c) => a + c.monto, 0));
  const mayores = gastos
      .sort((a, b) => b.monto - a.monto)
      .slice(0, 5)
      .map((t) => ({
        descripcion: (t.descripcion || "").slice(0, 40) || t.categoria,
        categoria: t.categoria,
        monto: redondear(t.monto),
      }));

  return {
    mes,
    movimientos: delMes.length,
    gastoTotal,
    ingresos: redondear(ingresos),
    balance: redondear(ingresos - gastoTotal),
    porCategoria,
    mayoresGastos: mayores,
  };
}

/// Lo que respondió la IA, recortado y validado: nunca se guarda ni se
/// muestra algo con otra forma.
function limpiarResumen(crudo) {
  let datos;
  try {
    datos = typeof crudo === "string" ? JSON.parse(crudo) : crudo;
  } catch (_) {
    return null;
  }
  if (!datos || typeof datos !== "object") return null;
  const texto = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
  const titular = texto(datos.titular, 120);
  const puntos = (Array.isArray(datos.puntos) ? datos.puntos : [])
      .map((p) => texto(p, 200))
      .filter(Boolean)
      .slice(0, 4);
  const consejo = texto(datos.consejo, 220);
  if (!titular || puntos.length === 0) return null;
  return {titular, puntos, consejo};
}

const NOMBRES_MES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
  "agosto", "septiembre", "octubre", "noviembre", "diciembre"];

function nombreMes(mes) {
  const [y, n] = mes.split("-").map(Number);
  return `${NOMBRES_MES[n - 1]} de ${y}`;
}

function mensajesParaIA({actual, anterior, moneda, nombreAsistente, enCurso}) {
  const sistema =
    `Eres ${nombreAsistente}, la asistente de finanzas personales de la app ` +
    "NeroMoney. Escribe un resumen mensual breve, cercano y honesto en " +
    "español de México, hablándole de tú al usuario. Usa SOLO los números " +
    "que te doy (nunca inventes cifras ni categorías); puedes redondearlos. " +
    `Los montos están en ${moneda}; escríbelos como $1,234. ` +
    "Compara con el mes anterior cuando sirva (sube/baja y por cuánto). " +
    "Sin regaños ni sermones; un tono amable y práctico. " +
    "Responde SOLO con un objeto JSON con esta forma exacta: " +
    '{"titular": "una frase de máximo 90 caracteres", ' +
    '"puntos": ["3 o 4 observaciones de máximo 140 caracteres cada una"], ' +
    '"consejo": "un consejo concreto y accionable de máximo 160 caracteres"}';
  const contexto = {
    mes: nombreMes(actual.mes),
    mesEnCurso: enCurso,
    esteMes: actual,
    mesAnterior: anterior.movimientos > 0 ? anterior : "sin movimientos",
  };
  return [
    {role: "system", content: sistema},
    {role: "user", content: JSON.stringify(contexto)},
  ];
}

module.exports = {
  mesActual,
  mesValido,
  mesAnterior,
  rangoMes,
  agregarMes,
  limpiarResumen,
  mensajesParaIA,
};
