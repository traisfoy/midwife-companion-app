import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '4000', 10),
  databaseUrl:
    process.env.DATABASE_URL ||
    'postgres://midwife_app:midwife_app@localhost:5432/midwife_companion',
  jwtSecret: process.env.JWT_SECRET || 'dev-only-change-me',
  orsApiKey: process.env.ORS_API_KEY || '',
  vapid: {
    publicKey: process.env.VAPID_PUBLIC_KEY || '',
    privateKey: process.env.VAPID_PRIVATE_KEY || '',
    subject: process.env.VAPID_SUBJECT || 'mailto:admin@example.com',
  },
};
