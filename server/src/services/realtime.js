// Socket.IO wiring. Clients authenticate with their JWT and join a room per
// identity; the server pushes dashboard/patient updates into those rooms.
import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { config } from '../config.js';

let io = null;

export function initRealtime(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: true, credentials: true },
  });

  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      socket.user = jwt.verify(token, config.jwtSecret);
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    const { role, id } = socket.user;
    socket.join(`${role}:${id}`);
  });

  return io;
}

export function emitToMidwife(midwifeId, event, payload) {
  io?.to(`midwife:${midwifeId}`).emit(event, payload);
}

export function emitToPatient(patientId, event, payload) {
  io?.to(`patient:${patientId}`).emit(event, payload);
}
