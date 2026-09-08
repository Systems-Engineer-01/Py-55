const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

/**
 * Cloud Function Trigger: Se ejecuta cuando se crea un nuevo documento en "viajes/{rideId}/calificaciones/{ratingId}".
 * Recalcula la calificación promedio del usuario o mototaxista calificado y la actualiza en Firestore.
 */
exports.updateUserRatingOnCreate = onDocumentCreated(
  "viajes/{rideId}/calificaciones/{ratingId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const data = snapshot.data();
    const targetUserId = data.aCalificado;

    if (!targetUserId) {
      console.log("Falta el campo aCalificado en la calificación");
      return;
    }

    const db = getFirestore();

    try {
      // Consultar todas las calificaciones de la subcolección agrupada "calificaciones" para este usuario
      const ratingsSnapshot = await db
        .collectionGroup("calificaciones")
        .where("aCalificado", "==", targetUserId)
        .get();

      if (ratingsSnapshot.empty) {
        console.log(`No hay calificaciones para el usuario ${targetUserId}`);
        return;
      }

      let totalStars = 0;
      let count = 0;

      ratingsSnapshot.forEach((doc) => {
        const ratingData = doc.data();
        if (typeof ratingData.estrellas === "number") {
          totalStars += ratingData.estrellas;
          count++;
        }
      });

      const averageRating = count > 0 ? parseFloat((totalStars / count).toFixed(2)) : 5.0;

      console.log(
        `Usuario ${targetUserId}: ${count} calificaciones procesadas, nuevo promedio: ${averageRating}`
      );

      // Actualizar la calificación en la colección de conductores
      const driverRef = db.collection("conductores").doc(targetUserId);
      const driverDoc = await driverRef.get();

      if (driverDoc.exists) {
        await driverRef.update({
          calificacion: averageRating,
          totalCalificaciones: count,
        });
      }

      // También actualizar en la colección de usuarios si existe
      const userRef = db.collection("usuarios").doc(targetUserId);
      const userDoc = await userRef.get();

      if (userDoc.exists) {
        await userRef.update({
          calificacionPromedio: averageRating,
        });
      }

      console.log(`Calificación del usuario ${targetUserId} actualizada exitosamente.`);
    } catch (error) {
      console.error("Error al actualizar la calificación promedio:", error);
    }
  }
);
