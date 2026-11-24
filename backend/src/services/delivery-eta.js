'use strict';

const AVERAGE_SPEED_KMH = 20;
const ARRIVAL_BUFFER_MINUTES = 5;

function estimateDeliveryEtaMinutes(distanceKm, outForDeliveryAt, now = new Date()) {
  const distance = Number(distanceKm);
  const startedAt = outForDeliveryAt ? new Date(outForDeliveryAt) : null;
  const currentTime = new Date(now);
  if (!Number.isFinite(distance) || distance <= 0 || distance > 250 ||
      !startedAt || Number.isNaN(startedAt.getTime()) ||
      Number.isNaN(currentTime.getTime())) return null;

  const expectedTotalMinutes = (distance / AVERAGE_SPEED_KMH) * 60 + ARRIVAL_BUFFER_MINUTES;
  const elapsedMinutes = Math.max(0, (currentTime.getTime() - startedAt.getTime()) / 60000);
  return Math.max(1, Math.ceil(expectedTotalMinutes - elapsedMinutes));
}

module.exports = { estimateDeliveryEtaMinutes };
