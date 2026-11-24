// Gastos compartidos (Pro): un grupo (pareja, familia, roomies) con gastos
// y metas en común. Crear el grupo requiere Pro; quien recibe el código se
// une gratis. Unirse, crear y salir pasan por aquí (no por el cliente)
// porque cambian la lista de miembros, que es lo que da acceso a los datos
// del grupo en firestore.rules.
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
require("./admin.js");
const {planVigente} = require("./planes.js");

const MAX_MIEMBROS = 6;
// Sin 0/O ni 1/I/L: el código se dicta o se copia a mano.
const ALFABETO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

function nuevoCodigo(azar = Math.random) {
  let codigo = "";
  for (let i = 0; i < 6; i++) codigo += ALFABETO[Math.floor(azar() * ALFABETO.length)];
  return codigo;
}

function limpiarNombre(valor, porDefecto) {
  const texto = typeof valor === "string" ? valor.trim().slice(0, 40) : "";
  return texto || porDefecto;
}

function normalizarCodigo(valor) {
  return (typeof valor === "string" ? valor : "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
}

function exigirSesion(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Inicia sesión primero.");
  return request.auth.uid;
}

exports.crearGrupo = onCall({region: "us-central1"}, async (request) => {
  const uid = exigirSesion(request);
  const db = getFirestore();
  const suscripcion = await db.collection("suscripciones").doc(uid).get();
  if (planVigente(suscripcion.data()) !== "pro") {
    throw new HttpsError("permission-denied", "Los gastos compartidos son parte del plan Pro.");
  }
  const usuarioRef = db.collection("usuarios").doc(uid);
  const nombre = limpiarNombre(request.data && request.data.nombre, "Nuestro hogar");
  const miNombre = limpiarNombre(request.data && request.data.miNombre, "Yo");

  return db.runTransaction(async (tx) => {
    const usuario = await tx.get(usuarioRef);
    if (usuario.get("grupoId")) {
      throw new HttpsError("failed-precondition", "Ya estás en un grupo. Sal de él para crear otro.");
    }
    // Un código que no exista ya (colisión casi imposible, pero se revisa).
    let codigo;
    for (let intento = 0; intento < 5; intento++) {
      const candidato = nuevoCodigo();
      if (!(await tx.get(db.collection("codigosGrupo").doc(candidato))).exists) {
        codigo = candidato;
        break;
      }
    }
    if (!codigo) throw new HttpsError("unavailable", "Intenta de nuevo.");
    const grupoRef = db.collection("grupos").doc();
    tx.set(grupoRef, {
      nombre,
      creador: uid,
      miembros: [uid],
      nombres: {[uid]: miNombre},
      codigo,
      creado: FieldValue.serverTimestamp(),
    });
    tx.set(db.collection("codigosGrupo").doc(codigo), {grupoId: grupoRef.id});
    tx.set(usuarioRef, {grupoId: grupoRef.id}, {merge: true});
    return {grupoId: grupoRef.id, codigo};
  });
});

exports.unirseAGrupo = onCall({region: "us-central1"}, async (request) => {
  const uid = exigirSesion(request);
  const codigo = normalizarCodigo(request.data && request.data.codigo);
  if (codigo.length !== 6) throw new HttpsError("invalid-argument", "El código tiene 6 letras y números.");
  const miNombre = limpiarNombre(request.data && request.data.miNombre, "Yo");
  const db = getFirestore();
  const usuarioRef = db.collection("usuarios").doc(uid);

  return db.runTransaction(async (tx) => {
    const usuario = await tx.get(usuarioRef);
    const enlace = await tx.get(db.collection("codigosGrupo").doc(codigo));
    if (!enlace.exists) throw new HttpsError("not-found", "No encontré un grupo con ese código.");
    const grupoRef = db.collection("grupos").doc(enlace.get("grupoId"));
    const grupo = await tx.get(grupoRef);
    if (!grupo.exists) throw new HttpsError("not-found", "Ese grupo ya no existe.");
    const miembros = grupo.get("miembros") || [];
    if (miembros.includes(uid)) return {grupoId: grupoRef.id};
    if (usuario.get("grupoId")) {
      throw new HttpsError("failed-precondition", "Ya estás en un grupo. Sal de él para unirte a otro.");
    }
    if (miembros.length >= MAX_MIEMBROS) {
      throw new HttpsError("resource-exhausted", `Un grupo puede tener hasta ${MAX_MIEMBROS} personas.`);
    }
    tx.update(grupoRef, {
      miembros: FieldValue.arrayUnion(uid),
      [`nombres.${uid}`]: miNombre,
    });
    tx.set(usuarioRef, {grupoId: grupoRef.id}, {merge: true});
    return {grupoId: grupoRef.id};
  });
});

/// Sale del grupo. Si era el último, el grupo y su código se borran (sus
/// gastos quedan huérfanos e inaccesibles; nadie más los veía).
exports.salirDeGrupo = onCall({region: "us-central1"}, async (request) => {
  const uid = exigirSesion(request);
  const db = getFirestore();
  const usuarioRef = db.collection("usuarios").doc(uid);
  return db.runTransaction(async (tx) => {
    const usuario = await tx.get(usuarioRef);
    const grupoId = usuario.get("grupoId");
    if (!grupoId) return {ok: true};
    const grupoRef = db.collection("grupos").doc(grupoId);
    const grupo = await tx.get(grupoRef);
    tx.update(usuarioRef, {grupoId: FieldValue.delete()});
    if (!grupo.exists) return {ok: true};
    const restantes = (grupo.get("miembros") || []).filter((m) => m !== uid);
    if (restantes.length === 0) {
      tx.delete(grupoRef);
      tx.delete(db.collection("codigosGrupo").doc(grupo.get("codigo")));
    } else {
      tx.update(grupoRef, {
        miembros: FieldValue.arrayRemove(uid),
        // El nombre se conserva: los gastos viejos siguen diciendo quién pagó.
        creador: grupo.get("creador") === uid ? restantes[0] : grupo.get("creador"),
      });
    }
    return {ok: true};
  });
});

exports._paraPruebas = {nuevoCodigo, normalizarCodigo, limpiarNombre, ALFABETO};
