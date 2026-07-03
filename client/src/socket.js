import { io } from 'socket.io-client';
import { getToken } from './api.js';

let socket = null;

// One socket per login session, authenticated with the JWT.
export function getSocket() {
  if (!socket) {
    socket = io('/', { auth: { token: getToken() } });
  }
  return socket;
}

export function resetSocket() {
  socket?.disconnect();
  socket = null;
}
