const mongoose = require("mongoose");

const {
  MONGO_HOST = "127.0.0.1",
  MONGO_PORT = "27017",
  MONGO_DB = "todo_devsecops",
} = process.env;

async function connectDB() {
  const uri = process.env.MONGO_DB_URI || `mongodb://${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}`;

  await mongoose.connect(uri, {
    autoIndex: true,
    serverSelectionTimeoutMS: 5000,
    socketTimeoutMS: 45000,
    family: 4,
  });

  console.log(`MongoDB connected to ${MONGO_HOST}:${MONGO_PORT}`);
}

module.exports = { connectDB };
