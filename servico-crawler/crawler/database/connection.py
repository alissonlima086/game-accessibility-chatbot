from pymongo import MongoClient
from config import settings
import logging

logger = logging.getLogger(__name__)

class MongoConnection:
    def __init__(self):
        self.client = None
        self.db = None

    def connect(self):
        try:
            self.client = MongoClient(settings.mongodb_url, serverSelectionTimeoutMS=5000)
            self.client.admin.command('ping')
            self.db = self.client[settings.mongodb_db]
            logger.info("Conexão com MongoDB estabelecida")
        except Exception as e:
            logger.error(f"Erro ao conectar ao MongoDB: {e}")
            raise

    def get_db(self):
        if self.db is None:
            raise Exception("Banco não conectado")
        return self.db

    def disconnect(self):
        try:
            if self.client:
                self.client.close()
                logger.info("Conexão com MongoDB fechada")
        except Exception as e:
            logger.error(f"Erro ao desconectar: {e}")

mongo_connection = MongoConnection()
